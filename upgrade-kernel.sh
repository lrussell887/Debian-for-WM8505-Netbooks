#!/bin/bash
set -e

REQUIRED_PACKAGES=(aria2 jq pv)

GITHUB_RELEASES=https://api.github.com/repos/lrussell887/Debian-for-WM8505-Netbooks/releases/latest

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
    log INFO "Cleaning up"
    mountpoint -q /tmp/boot && umount /tmp/boot
    rm -rf /tmp/upgrade.tar.gz* /tmp/upgrade /tmp/boot
    exit
}

if [ ! -f /proc/device-tree/model ] || [ "$(tr -d '\0' < /proc/device-tree/model)" != "Wondermedia WM8505 Netbook" ]; then
    log ERROR "This script must be run on your netbook"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    log ERROR "This script must be run as root or with sudo"
    exit 1
fi

if [ "$(df --output=avail / | tail -n 1 | xargs)" -le 4000000 ]; then
    log ERROR "At least 4GB of free space is required"
    exit 1
fi

log INFO "Starting kernel upgrade"

trap cleanup EXIT
trap 'log ERROR "Upgrade error"' ERR

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

current_kernel=$(uname -r | cut -d'-' -f1)
log INFO "Current kernel: $current_kernel"

releases_json=$(wget -q -O - "$GITHUB_RELEASES")
latest_kernel=$(echo "$releases_json" | jq -r '.tag_name' | cut -d'-' -f1)
log INFO "Latest kernel: $latest_kernel"

if [ "$(printf '%s\n' "$current_kernel" "$latest_kernel" | sort -V | tail -n 1)" == "$current_kernel" ]; then
    log WARN "Kernel already up-to-date"
    exit 0
fi

log INFO "Downloading upgrade tarball"
upgrade_url=$(echo "$releases_json" | jq -r '.assets[] | select(.name | startswith("upgrade")) | .browser_download_url')
aria2c --console-log-level=error --summary-interval=0 -d /tmp -o upgrade.tar.gz "$upgrade_url"
log OK "Downloaded tarball"

log INFO "Extracting tarball"
mkdir /tmp/upgrade
pv /tmp/upgrade.tar.gz | tar -xzf - -C /tmp/upgrade
log OK "Extracted tarball"

log INFO "Installing boot images"
mkdir /tmp/boot
mount /dev/mmcblk0p1 /tmp/boot
rm -rf /tmp/boot/*
mv /tmp/upgrade/boot/* /tmp/boot/
log OK "Installed boot images"

log INFO "Installing kernel modules"
rm -rf /lib/modules/*
mv /tmp/upgrade/rootfs/lib/modules/* /lib/modules/

log OK "Kernel upgrade complete"

read -rp "Reboot now? (y/n) " reboot
[[ $reboot == [yY] ]] && {
    reboot
    exit 0
}

log WARN "Please reboot as soon as possible to complete the upgrade."
exit 0
