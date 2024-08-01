#!/bin/bash
set -e
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
export CFLAGS="-march=armv5te -mtune=arm926ej-s"

KERNEL_REPO=https://github.com/lrussell887/linux-vtwm.git
KERNEL_BRANCH=kernel
KERNEL_DIR=linux-vtwm
KERNEL_VERSION_PATTERN="^6\.1\."

KERNEL_UPSTREAM_RELEASES=https://www.kernel.org/releases.json
KERNEL_UPSTREAM_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

DEBIAN_LINUX_CONFIG_URL=https://packages.debian.org/bookworm/armel/linux-config-6.1/download
DEBIAN_LINUX_CONFIG_FILE=./usr/src/linux-config-6.1/config.armel_none_marvell.xz

log() {
    local level=$1
    shift
    case $level in
        OK) echo "$(tput setaf 2)[OK]$(tput sgr0) $*" ;;
        INFO) echo "$(tput setaf 6)[INFO]$(tput sgr0) $*" ;;
        WARN) echo "$(tput setaf 3)[WARN]$(tput sgr0) $*" ;;
        ERROR) echo "$(tput setaf 1)[ERROR]$(tput sgr0) $*" ;;
    esac
}

# shellcheck disable=SC2329
cleanup() {
    local rc=$?
    pwd | grep -q "$KERNEL_DIR" && popd

    log INFO "Checking disk image mounts"
    mountpoint -q boot && umount boot
    mountpoint -q rootfs && umount rootfs
    [ -n "$loopdev" ] && losetup | grep -q "$loopdev" && losetup -d "$loopdev"

    log INFO "Cleaning up temp files"
    rm -rf .config .config.armel_none_marvell .config.old .linux-config.deb .seed.new .zImage_w_dtb boot rootfs

    if [ -d "$KERNEL_DIR" ]; then
        pushd "$KERNEL_DIR"
        log INFO "Cleaning up kernel repo"
        find .git -maxdepth 1 -type d -name 'rebase-*' | grep -q . && git rebase --abort
        git checkout -f "$KERNEL_BRANCH"
        git branch --list rebase | grep -q . && git branch -D rebase
    fi

    log OK "Cleanup complete"
    exit "$rc"
}

if [ "$(id -u)" -ne 0 ]; then
    log ERROR "Run as root or with sudo"
    exit 1
fi

if [ -d build ]; then
    log ERROR "Build directory exists; remove it to rebuild"
    exit 1
fi

trap cleanup EXIT
trap 'log ERROR "Build error"' ERR
trap 'exit $?' INT TERM

log INFO "Starting build"

if [ ! -d "$KERNEL_DIR" ]; then
    log INFO "Cloning kernel repo"
    git clone $KERNEL_REPO $KERNEL_DIR
fi

pushd $KERNEL_DIR

log INFO "Resetting kernel repo"
git checkout $KERNEL_BRANCH
git fetch origin
git reset --hard origin/$KERNEL_BRANCH
git clean -fdx

kernel_version=$(make kernelversion)
log INFO "Kernel version: $kernel_version"

if [[ ! "$kernel_version" =~ $KERNEL_VERSION_PATTERN ]]; then
    log ERROR "Unexpected kernel version"
    exit 1
fi

upstream_version=$(curl -s $KERNEL_UPSTREAM_RELEASES | jq -r '.releases[].version' | grep $KERNEL_VERSION_PATTERN)

if [ "$(printf '%s\n' "$kernel_version" "$upstream_version" | sort -V | head -n 1)" != "$upstream_version" ]; then
    log WARN "Out of date, rebasing to $upstream_version"
    git config user.name "user"
    git config user.email "user@example.com"
    git checkout -b rebase "$KERNEL_BRANCH^2"
    git fetch --no-tags $KERNEL_UPSTREAM_REPO v"$upstream_version"
    git rebase FETCH_HEAD
    new_tree=$(git commit-tree -p refs/heads/$KERNEL_BRANCH -p HEAD -m "rebase v$upstream_version" 'HEAD^{tree}')
    git update-ref refs/heads/$KERNEL_BRANCH "$new_tree"
    git checkout $KERNEL_BRANCH
    git branch -D rebase
    kernel_version=$(make kernelversion)
    log OK "Rebase complete"
fi

if find ../patches -maxdepth 1 -type f -name '*.patch' | grep -q .; then
    log INFO "Applying patches"
    for patch in ../patches/*.patch; do
        patch -p0 < "$patch"
        log OK "Patch $patch applied"
    done
    git add .
    git commit -m "Apply patches"
fi

popd

log INFO "Retrieving Debian config"
curl -o .linux-config.deb "$(lynx -dump -nonumbers -listonly $DEBIAN_LINUX_CONFIG_URL | grep '\.deb$' | head -n 1)"
log INFO "Extracting config"
ar p .linux-config.deb data.tar.xz | tar -xOJf - $DEBIAN_LINUX_CONFIG_FILE | unxz > .config.armel_none_marvell
log OK "Config retrieved"

log INFO "Generating olddefconfig"
cp seed .config
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config olddefconfig
log INFO "Extracting enabled options"
grep '=y' .config > .seed.new
log INFO "Merging configs"
$KERNEL_DIR/scripts/kconfig/merge_config.sh -m .config.armel_none_marvell seed
$KERNEL_DIR/scripts/kconfig/merge_config.sh -m .config .seed.new
log INFO "Finalizing config"
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config olddefconfig
log OK "Config created"

log INFO "Compiling kernel"
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config -j"$(nproc)" zImage wm8505-ref.dtb
log INFO "Compiling modules"
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config -j"$(nproc)" modules
log OK "Kernel and modules built"

log INFO "Creating disk image"
mkdir build
disk_file="build/disk_$kernel_version.img"
dd if=/dev/zero of="$disk_file" bs=1M count=3500
log INFO "Partitioning disk image"
parted "$disk_file" --script mklabel msdos
parted "$disk_file" --script mkpart primary fat32 1MiB 34MiB
parted "$disk_file" --script mkpart primary ext4 34MiB 100%
log INFO "Creating loop device"
loopdev=$(losetup -fP --show "$disk_file")
log INFO "Formatting disk image"
mkfs.vfat -F 32 -n BOOT "$loopdev"p1
mkfs.ext4 -L rootfs "$loopdev"p2
log INFO "Mounting disk image"
mkdir boot rootfs
mount "$loopdev"p1 boot
mount "$loopdev"p2 rootfs
log OK "Disk image mounted"

log INFO "Building boot images"
cat $KERNEL_DIR/arch/arm/boot/zImage $KERNEL_DIR/arch/arm/boot/dts/wm8505-ref.dtb > .zImage_w_dtb
mkdir boot/script
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d .zImage_w_dtb boot/script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d cmd boot/script/scriptcmd
log OK "Boot created"

log INFO "Installing modules into rootfs"
make -C $KERNEL_DIR INSTALL_MOD_PATH=../rootfs modules_install
log INFO "Creating upgrade tarball"
tar --use-compress-program="pigz --best" -cf "build/upgrade_$kernel_version.tar.gz" boot rootfs
log INFO "Building rootfs"
multistrap -f multistrap.conf
log INFO "Merging ship folder"
cp -r ship/. rootfs/
log INFO "Configuring rootfs"
systemd-nspawn --resolv-conf=off --timezone=off -D rootfs -E QEMU_CPU=arm926 -P /bin/sh < config-rootfs.sh
log OK "Rootfs created"

log INFO "Unmounting disk image"
umount boot rootfs
log INFO "Zeroing free blocks"
zerofree "$loopdev"p2
log INFO "Detaching loop device"
losetup -d "$loopdev"
log INFO "Compressing disk image"
pigz --best "$disk_file"

log OK "Build complete"
exit 0
