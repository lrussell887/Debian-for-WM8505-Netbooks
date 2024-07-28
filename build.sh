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
    [ "$(dirs -p | wc -l)" -gt 1 ] && popd
    log INFO "Cleaning up previous build files"
    rm -rf .config .config.armel_none_marvell .config.old .seed.new .zImage_w_dtb modules/ rootfs/ script/
    if [ -d "$KERNEL_DIR" ]; then
        pushd "$KERNEL_DIR"
        log INFO "Cleaning kernel repo"
        git rebase --abort || true
        git checkout -f "$KERNEL_BRANCH"
        git branch -D rebase || true
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

current_version=$(make kernelversion)

if [[ ! "$current_version" =~ $KERNEL_VERSION_PATTERN ]]; then
    log ERROR "Unexpected kernel version"
    exit 1
fi
log OK "Kernel version: $current_version"

upstream_version=$(curl -s $KERNEL_UPSTREAM_RELEASES | jq -r '.releases[].version' | grep $KERNEL_VERSION_PATTERN)

if [ "$(printf '%s\n' "$current_version" "$upstream_version" | sort -V | head -n 1)" != "$upstream_version" ]; then
    log WARN "Out of date, rebasing to $upstream_version"
    git config user.name "user"
    git config user.email "user@example.com"
    git checkout -b rebase "$KERNEL_BRANCH^2"
    git fetch --no-tags $KERNEL_UPSTREAM_REPO v"$upstream_version"
    git rebase FETCH_HEAD
    new_tree=$(git commit-tree -p refs/heads/$KERNEL_BRANCH -p HEAD -m "rebase v$upstream_version" 'HEAD^{tree}')
    git update-ref refs/heads/$KERNEL_BRANCH "$new_tree"
    git checkout $KERNEL_BRANCH
    log OK "Rebase complete"
fi

log INFO "Applying patches"
for patch in ../patches/*.patch; do
    patch -p0 < "$patch"
    log OK "Patch $patch applied"
done
git add .
git commit -m "Apply patches"

popd

log INFO "Retrieving Debian config"
curl -o .linux-config.deb "$(lynx -dump -nonumbers -listonly $DEBIAN_LINUX_CONFIG_URL | grep '\.deb$' | head -n 1)"
log INFO "Extracting config"
ar p .linux-config.deb data.tar.xz | tar -xOJf - $DEBIAN_LINUX_CONFIG_FILE | unxz > .config.armel_none_marvell
rm .linux-config.deb
log OK "Config retrieved"

log INFO "Generating olddefconfig"
cp seed .config
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config olddefconfig
log INFO "Extracting enabled options"
grep -E '=y' .config > .seed.new
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

log INFO "Building boot images"
cat $KERNEL_DIR/arch/arm/boot/zImage $KERNEL_DIR/arch/arm/boot/dts/wm8505-ref.dtb > .zImage_w_dtb
mkdir -p script
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d .zImage_w_dtb script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d cmd script/scriptcmd
log INFO "Creating boot archive"
mkdir -p build
zip -r build/boot.zip script/
log OK "boot.zip created"

log INFO "Building rootfs"
multistrap -f multistrap.conf
log INFO "Moving init for setup"
mv rootfs/sbin/init rootfs/sbin/init.orig
log INFO "Merging ship folder"
cp -r ship/. rootfs/
log INFO "Installing modules"
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config INSTALL_MOD_PATH=../rootfs modules_install
log INFO "Creating rootfs archive"
tar -C rootfs --use-compress-program=pigz -cf build/rootfs.tar.gz .
log OK "rootfs.tar.gz created"

log INFO "Installing modules"
mkdir -p modules
make -C $KERNEL_DIR KCONFIG_CONFIG=../.config INSTALL_MOD_PATH=../modules modules_install
log INFO "Creating modules archive"
tar -C modules --use-compress-program=pigz -cf build/modules.tar.gz .
log OK "modules.tar.gz created"

log OK "Build complete"
exit 0
