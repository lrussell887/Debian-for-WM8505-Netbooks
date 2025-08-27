#!/bin/bash
set -e

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-
export CFLAGS='-march=armv5te -mtune=arm926ej-s'

REQUIRED_PACKAGES=(
	bc binfmt-support bison build-essential debian-archive-keyring dosfstools
	e2fsprogs flex gcc-arm-linux-gnueabi git jq libssl-dev lynx mmdebstrap
	parted pigz pv qemu-user-static u-boot-tools zerofree
)

KERNEL_REPO=https://github.com/lrussell887/linux-vtwm.git
KERNEL_BRANCH=kernel
KERNEL_DIR=linux-vtwm
KERNEL_VERSION_PATTERN='^6\.12\.'

KERNEL_UPSTREAM_RELEASES=https://www.kernel.org/releases.json
KERNEL_UPSTREAM_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git

DEBIAN_LINUX_POOL=https://ftp.debian.org/debian/pool/main/l/linux/
DEBIAN_LINUX_CONFIG_PATTERN='linux-config-6.12_.*_armel\.deb$'
DEBIAN_LINUX_CONFIG_FILE=./usr/src/linux-config-6.12/config.armel_none_rpi.xz

DEBIAN_EXTRA_PACKAGES="cloud-guest-utils dropbear firmware-mediatek gpiod htop network-manager sudo wireless-regdb wpasupplicant"
DEBIAN_COMPONENTS="main non-free-firmware"
DEBIAN_MIRROR="http://deb.debian.org/debian"

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
	umount -l boot rootfs 2>/dev/null || true
	losetup -d "$loopdev" 2>/dev/null || true
	rm -rf disk.img boot rootfs

	if [ -d "$KERNEL_DIR" ]; then
		cd "$KERNEL_DIR"
		git rebase --abort 2>/dev/null || true
		[ "$(git branch --show-current)" != "$KERNEL_BRANCH" ] && git switch -f "$KERNEL_BRANCH"
		git branch -D rebase 2>/dev/null || true
	fi

	exit
}

if [ -z "$(which apt-get)" ]; then
	log ERROR "This script requires a Debian or Ubuntu-based system"
	exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
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
	git clone "$KERNEL_REPO" "$KERNEL_DIR"
	log OK "Cloned kernel"
fi

if [ -f "$KERNEL_DIR/.build_complete" ]; then
	log WARN "A previous kernel exists; rebuild to upgrade"
	ask "Rebuild kernel?" || skip_kernel=true
fi

if [ -z "$skip_kernel" ]; then (
	cd "$KERNEL_DIR"

	log INFO "Resetting kernel repo"
	git fetch origin
	git switch -f "$KERNEL_BRANCH"
	git reset --hard "origin/$KERNEL_BRANCH"
	git clean -fdx -q

	current_kernel=$(make kernelversion)
	log INFO "Current kernel: $current_kernel"

	if [[ ! "$current_kernel" =~ $KERNEL_VERSION_PATTERN ]]; then
		log ERROR "Unexpected kernel version"
		exit 1
	fi

	upstream_kernel=$(wget -q -O - "$KERNEL_UPSTREAM_RELEASES" | jq -r '.releases[].version' | grep "$KERNEL_VERSION_PATTERN")
	log INFO "Upstream kernel: $upstream_kernel"

	if [ "$(printf '%s\n' "$current_kernel" "$upstream_kernel" | sort -V | tail -n 1)" != "$current_kernel" ]; then
		log WARN "Kernel repo out-of-date, upgrading"

		if ! git config --get user.name >/dev/null || ! git config --get user.email >/dev/null; then
			log WARN "Git identity missing, using temporary one"
			git config user.name "user"
			git config user.email "user@example.com"
		fi

		git switch -c rebase "$KERNEL_BRANCH^2"
		git fetch --no-tags "$KERNEL_UPSTREAM_REPO" "v$upstream_kernel"
		git rebase FETCH_HEAD
		git switch "$KERNEL_BRANCH"
		git merge --no-ff -m "rebase v$upstream_kernel" rebase
		git branch -D rebase
		log OK "Upgraded kernel"
	fi

	log INFO "Applying patches"
	while IFS= read -r -d '' patch; do
		git apply "$patch"
	done < <(find ../patches -maxdepth 1 -type f -name '*.patch' -print0)
	log OK "Applied patches"

	log INFO "Retrieving Debian config"
	deb_url=$(lynx -dump -listonly -nonumbers "$DEBIAN_LINUX_POOL" | grep "$DEBIAN_LINUX_CONFIG_PATTERN" | tail -n 1)
	wget -O .linux-config.deb "$deb_url"
	log INFO "Extracting config"
	ar p .linux-config.deb data.tar.xz | tar -xOJf - "$DEBIAN_LINUX_CONFIG_FILE" | unxz > .config.debian
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
	make LOCALVERSION= -j"$(nproc)" zImage vt8500/wm8505-ref.dtb
	cat arch/arm/boot/zImage arch/arm/boot/dts/vt8500/wm8505-ref.dtb > zImage_w_dtb
	log INFO "Building modules"
	make LOCALVERSION= -j"$(nproc)" modules
	touch .build_complete
	log OK "Built kernel and modules"
) fi

log INFO "Creating disk image"
dd if=/dev/zero of=disk.img bs=1M count=3500 conv=fsync
log INFO "Partitioning disk image"
parted disk.img --script mklabel msdos
parted disk.img --script mkpart primary fat32 1MiB 34MiB
parted disk.img --script mkpart primary ext4 34MiB 100%
log INFO "Setting up loop device"
loopdev=$(losetup -fP --show disk.img)
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
mkimage -A arm -O linux -T kernel -C none -a 0x8000 -e 0x8000 -n linux -d "$KERNEL_DIR/zImage_w_dtb" boot/script/uzImage.bin
mkimage -A arm -O linux -T script -C none -a 1 -e 0 -n "script image" -d boot.cmd boot/script/scriptcmd
log OK "Boot ready"

log INFO "Bootstrapping rootfs"
# shellcheck disable=SC2016
mmdebstrap \
	--variant=standard \
	--include="$DEBIAN_EXTRA_PACKAGES" \
	--architectures=armel \
	--components="$DEBIAN_COMPONENTS" \
	--setup-hook='cp -r overlay/. "$1"/' \
	--customize-hook='chroot "$1" /bin/sh < config-rootfs.sh' \
	trixie \
	rootfs \
	"$DEBIAN_MIRROR"
log OK "Rootfs ready"

log INFO "Installing modules"
make -C "$KERNEL_DIR" INSTALL_MOD_PATH=../rootfs modules_install
log OK "Installed modules"

log INFO "Creating upgrade tarball"
kernel_release=$(make -C "$KERNEL_DIR" LOCALVERSION= -s kernelrelease)
archive_paths=("boot" "rootfs/lib/modules/$kernel_release")
upgrade_size=$(du -sb "${archive_paths[@]}" | awk '{sum += $1} END {print sum}')
mkdir build
tar -cf - "${archive_paths[@]}" | pv -s "$upgrade_size" | pigz -9 > "build/upgrade-$kernel_release.tar.gz"
log OK "Created upgrade tarball"

log INFO "Unmounting disk image"
umount boot rootfs
log INFO "Zeroing free blocks"
zerofree "$loopdev"p2
log INFO "Detaching loop device"
losetup -d "$loopdev"
log INFO "Compressing disk image"
pv disk.img | pigz -9 > "build/disk-$kernel_release.img.gz"
log INFO "Fixing permissions"
[ -n "$SUDO_USER" ] && chown -R "$SUDO_UID:$SUDO_GID" build
log OK "Build complete"
exit 0
