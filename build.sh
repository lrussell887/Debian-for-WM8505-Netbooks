# !/bin/bash
set -x

# Extract a copy of the kernel
tar xf kernel.tar.xz

# Fix screen contrast bug
# See https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ
sed -i 's/fbi->contrast = 0x10/fbi->contrast = 0x80/g' kernel/drivers/video/fbdev/wm8505fb.c

# Build the kernel configuration file
# The baseconfig file is from archived Debian kernel package "linux-source-4.5_4.5.4-1"
# The seed modifies the config to match architecture and other settings
./kernel/scripts/kconfig/merge_config.sh -m baseconfig seed
mv .config config
make -C kernel ARCH=arm KCONFIG_CONFIG=../config olddefconfig

# Build the kernel
make -C kernel ARCH=arm KCONFIG_CONFIG=../config CROSS_COMPILE=arm-linux-gnueabi- CFLAGS="-march=armv5te -mtune=arm926ej-s" -j$(nproc) zImage wm8505-ref.dtb
cat kernel/arch/arm/boot/zImage kernel/arch/arm/boot/dts/wm8505-ref.dtb > zImage_w_dtb

# Build the kernel and boot images
mkdir -p script
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d zImage_w_dtb script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d cmd script/scriptcmd

# Build the kernel modules
make -C kernel ARCH=arm KCONFIG_CONFIG=../config CROSS_COMPILE=arm-linux-gnueabi- CFLAGS="-march=armv5te -mtune=arm926ej-s" -j$(nproc) CFLAGS_MODULE=-fno-pic modules

# Append standard Debian packages to multistrap.conf
# The aptitude search is based on tasksel's "standard system utilities"
# Since package 'dmidecode' is not present on armel, it is removed
aptitude search ~pstandard ~prequired ~pimportant -F%p | tr '\n' ' ' | sed 's/dmidecode //g' >> multistrap.conf

# Build the rootfs
multistrap -a armel -f multistrap.conf

# Merge ship folder into rootfs
# It contains configuration for hosts, networking, display, and swap
cp -a ship/. rootfs/

# Configure the rootfs
# Dash pre-inst is required, as dpkg will fail without it
# The root password is disabled, and swapfile service enabled
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true LC_ALL=C LANGUAGE=C LANG=C
cp /usr/bin/qemu-arm-static rootfs/usr/bin
mount -o bind /dev/ rootfs/dev/
chroot rootfs /var/lib/dpkg/info/dash.preinst install
chroot rootfs dpkg --configure -a
chroot rootfs passwd -d root
chroot rootfs systemctl enable swapfile.service
rm rootfs/usr/bin/qemu-arm-static
umount rootfs/dev

# Install kernel modules into rootfs
# Also delete the broken symlinks to build and source folders
make -C kernel ARCH=arm KCONFIG_CONFIG=../config INSTALL_MOD_PATH=../rootfs modules_install
rm rootfs/lib/modules/4.5.0/build rootfs/lib/modules/4.5.0/source

# Build the boot and rootfs archives
zip -r boot.zip script/
tar -C rootfs -czf rootfs.tar.gz .
