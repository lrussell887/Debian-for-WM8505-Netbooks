#!/bin/bash
set -xe
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
export CFLAGS="-march=armv5te -mtune=arm926ej-s"

# Get a copy of the kernel, specifically wh0's rebase v6.1.44 commit from GitHub
if [ ! -f "kernel-6.1.44.tar.gz" ]; then
    wget https://github.com/wh0/bookconfig/archive/73f9c8153576860d61abd987acdb5e2773aeafca.tar.gz -O kernel-6.1.44.tar.gz
fi
mkdir -p kernel
tar -C kernel -xzf kernel-6.1.44.tar.gz --strip-components=1

# Fix screen contrast bug
# See https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ
sed -i 's/fbi->contrast = 0x10/fbi->contrast = 0x80/g' kernel/drivers/video/fbdev/wm8505fb.c

# Build the kernel configuration file
# Create a seeded defconfig
cp seed .config
make -C kernel KCONFIG_CONFIG=../.config olddefconfig
# Extract the enabled config options to make a defconfig seed
grep -E '=y' .config > .defconfig_seed
# Create a seeded Debian kernel config file based on armel_none_marvell from linux-config-6.1
./kernel/scripts/kconfig/merge_config.sh -m config.armel_none_marvell seed
# Merge the defconfig seed into the Debian kernel config
./kernel/scripts/kconfig/merge_config.sh -m .config .defconfig_seed
# Generate final kernel config
make -C kernel KCONFIG_CONFIG=../.config olddefconfig

# Build the kernel
make -C kernel KCONFIG_CONFIG=../.config -j$(nproc) zImage wm8505-ref.dtb
cat kernel/arch/arm/boot/zImage kernel/arch/arm/boot/dts/wm8505-ref.dtb > zImage_w_dtb

# Build the kernel modules
make -C kernel KCONFIG_CONFIG=../.config -j$(nproc) modules

# Build the kernel image and boot image
mkdir -p script
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d zImage_w_dtb script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d cmd script/scriptcmd

# Build the rootfs
multistrap -f multistrap.conf

# Move init for first boot setup
mv rootfs/sbin/init rootfs/sbin/init.orig

# Merge ship folder into rootfs
cp -r ship/. rootfs/

# Install kernel modules into rootfs
make -C kernel KCONFIG_CONFIG=../.config INSTALL_MOD_PATH=../rootfs modules_install

# Build the boot and rootfs archives
zip -r boot.zip script/
tar -C rootfs -czf rootfs.tar.gz .
