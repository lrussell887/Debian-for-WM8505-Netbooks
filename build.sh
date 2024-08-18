#!/bin/bash
set -e

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
export CFLAGS='-march=armv5te -mtune=arm926ej-s'

REQUIRED_PACKAGES=(
    bc binfmt-support bison build-essential debian-archive-keyring dosfstools
    e2fsprogs flex gcc-arm-linux-gnueabi git jq libssl-dev lynx multistrap
    parted pigz qemu-user-static systemd-container u-boot-tools zerofree
)

KERNEL_REPO=https://github.com/lrussell887/linux-vtwm.git
KERNEL_BRANCH=kernel
KERNEL_DIR=linux-vtwm
KERNEL_VERSION_PATTERN='^6\.1\.'

KERNEL_UPSTREAM_RELEASES=https://www.kernel.org/releases.json
KERNEL_UPSTREAM_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

DEBIAN_LINUX_POOL=https://ftp.debian.org/debian/pool/main/l/linux/
DEBIAN_LINUX_CONFIG_PATTERN='linux-config-6.1_.*_armel\.deb$'
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

ask() {
    local prompt=$1
    while true; do
        read -rp "$prompt [y/n]: " yn
        case $yn in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
        esac
    done
}

# shellcheck disable=SC2329
cleanup() {
    log INFO "Cleaning up"
    mountpoint -q boot && umount boot
    mountpoint -q rootfs && umount rootfs
    rm -rf boot rootfs
    [ -n "$loopdev" ] && losetup | grep -q "^$loopdev" && losetup -d "$loopdev"

    if [ -d "$KERNEL_DIR" ]; then
        cd "$KERNEL_DIR"
        [ -n "$(find .git -maxdepth 1 -type d -name 'rebase-*')" ] && git rebase --abort
        git checkout -f "$KERNEL_BRANCH"
        [ -n "$(git branch --list rebase)" ] && git branch -D rebase
    fi

    exit
}

if [ -z "$(which apt-get)" ]; then
    log ERROR "This script requires a Debian or Ubuntu-based system"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    log ERROR "This script must be run as root or with sudo"
    exit 1
fi

if [ -d build ]; then
    log WARN "A previous build exists; remove to rebuild"
    ask "Remove build directory?" || exit 1
    rm -r build
fi

log INFO "Starting build"
trap cleanup EXIT
trap 'log ERROR "Build error"' ERR

mapfile -t missing_pkgs < <(
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$' || echo "$pkg"
    done
)

if [ ${#missing_pkgs[@]} -ne 0 ]; then
    log WARN "Installing missing packages: ${missing_pkgs[*]}"
    apt-get install -y "${missing_pkgs[@]}"
    log OK "Installed packages"
fi

if [ ! -d "$KERNEL_DIR" ]; then
    log INFO "Cloning kernel repo"
    git clone $KERNEL_REPO $KERNEL_DIR
    log OK "Cloned kernel"
fi

if [ -f $KERNEL_DIR/vmlinux ] && [ -f $KERNEL_DIR/modules.order ]; then
    log WARN "A previous kernel exists; rebuild to upgrade"
    ask "Rebuild kernel?" || skip_kernel=true
fi

if [ -z "$skip_kernel" ]; then (
    cd $KERNEL_DIR

    log INFO "Resetting kernel repo"
    git fetch origin
    git reset --hard origin/$KERNEL_BRANCH
    git clean -fdx -q

    current_kernel=$(make kernelversion)
    log INFO "Current kernel: $current_kernel"

    if [[ ! "$current_kernel" =~ $KERNEL_VERSION_PATTERN ]]; then
        log ERROR "Unexpected kernel version"
        exit 1
    fi

    upstream_kernel=$(wget -q -O - $KERNEL_UPSTREAM_RELEASES | jq -r '.releases[].version' | grep $KERNEL_VERSION_PATTERN)
    log INFO "Upstream kernel: $upstream_kernel"

    if [ "$(printf '%s\n' "$current_kernel" "$upstream_kernel" | sort -V | tail -n 1)" != "$current_kernel" ]; then
        log WARN "Kernel repo out-of-date, upgrading"
        git config user.name "user"
        git config user.email "user@example.com"
        git checkout -b rebase "$KERNEL_BRANCH^2"
        git fetch --no-tags $KERNEL_UPSTREAM_REPO v"$upstream_kernel"
        git rebase FETCH_HEAD
        new_tree=$(git commit-tree -p refs/heads/$KERNEL_BRANCH -p HEAD -m "rebase v$upstream_kernel" 'HEAD^{tree}')
        git update-ref refs/heads/$KERNEL_BRANCH "$new_tree"
        git checkout $KERNEL_BRANCH
        git branch -D rebase
        log OK "Upgraded kernel"
    fi

    log INFO "Applying patches"
    while IFS= read -r -d '' patch; do
        patch -p0 < "$patch"
    done < <(find ../patches -maxdepth 1 -type f -name '*.patch' -print0)

    if [ -n "$(git status --porcelain)" ]; then
        git add .
        git commit -m "Apply patches"
        log OK "Applied patches"
    fi

    log INFO "Retrieving Debian config"
    deb_url=$(lynx -dump -listonly -nonumbers $DEBIAN_LINUX_POOL | grep "$DEBIAN_LINUX_CONFIG_PATTERN" | tail -n 1)
    wget -O .linux-config.deb "$deb_url"
    log INFO "Extracting config"
    ar p .linux-config.deb data.tar.xz | tar -xOJf - $DEBIAN_LINUX_CONFIG_FILE | unxz > .config.debian
    log OK "Retrieved config"

    log INFO "Generating seeded default config"
    cp ../seed .config
    make olddefconfig
    log INFO "Creating default config seed"
    grep '=y' .config > .seed.defconfig
    log INFO "Merging with Debian config"
    scripts/kconfig/merge_config.sh -m .config.debian ../seed
    scripts/kconfig/merge_config.sh -m .config .seed.defconfig
    log INFO "Finalizing config"
    make olddefconfig
    log OK "Config created"

    log INFO "Building kernel"
    make -j"$(nproc)" zImage wm8505-ref.dtb
    cat arch/arm/boot/zImage arch/arm/boot/dts/wm8505-ref.dtb > zImage_w_dtb
    log INFO "Building modules"
    make -j"$(nproc)" modules
    log OK "Built kernel and modules"
) fi

log INFO "Creating disk image"
kernel_version=$(make -C $KERNEL_DIR -s kernelversion)
disk_file="build/disk-$kernel_version.img"
mkdir build
dd if=/dev/zero of="$disk_file" bs=1M count=3500 conv=fsync
log INFO "Partitioning disk image"
parted "$disk_file" --script mklabel msdos
parted "$disk_file" --script mkpart primary fat32 1MiB 34MiB
parted "$disk_file" --script mkpart primary ext4 34MiB 100%
log INFO "Setting up loop device"
loopdev=$(losetup -fP --show "$disk_file")
log INFO "Formatting disk image"
mkfs.vfat -F 32 -n BOOT "$loopdev"p1
mkfs.ext4 -L rootfs "$loopdev"p2
log INFO "Mounting disk image"
mkdir boot rootfs
mount "$loopdev"p1 boot
mount "$loopdev"p2 rootfs
log OK "Disk image mounted"

log INFO "Generating boot images"
mkdir boot/script
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d $KERNEL_DIR/zImage_w_dtb boot/script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d cmd boot/script/scriptcmd
log OK "Boot ready"

log INFO "Installing modules"
make -C $KERNEL_DIR INSTALL_MOD_PATH=../rootfs modules_install
log INFO "Creating upgrade tarball"
tar --use-compress-program="pigz -9" -cf "build/upgrade-$kernel_version.tar.gz" boot rootfs
log INFO "Bootstrapping rootfs"
multistrap -f multistrap.conf
log INFO "Merging ship folder"
cp -r ship/. rootfs/
log INFO "Configuring rootfs"
systemd-nspawn --resolv-conf=off --timezone=off -D rootfs -P /bin/sh < config-rootfs.sh
log INFO "Creating swap file"
dd if=/dev/zero of=rootfs/swapfile bs=1M count=256 conv=fsync
chmod 600 rootfs/swapfile
mkswap rootfs/swapfile
log OK "Rootfs ready"

log INFO "Unmounting disk image"
umount boot rootfs
log INFO "Zeroing free blocks"
zerofree "$loopdev"p2
log INFO "Detaching loop device"
losetup -d "$loopdev"
log INFO "Compressing disk image"
pigz -9 "$disk_file"

log OK "Build complete"
exit 0
