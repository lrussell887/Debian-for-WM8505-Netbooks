# WMT OS Build Settings
#
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

export NICE="${NICE:-19}" # Niceness value

export ARCH="arm"
export CROSS_COMPILE="arm-linux-gnueabi-"
export KCFLAGS="-march=armv5te -mtune=arm926ej-s"
export KBUILD_BUILD_VERSION=1 # Deterministic uname -v '#1'

export KERNEL_BRANCH="wmt-6.12.y"
export KERNEL_REPO="https://github.com/wmt-os/linux-wmt.git"

export BUILDER_NAME="WMT OS Builder"
export BUILDER_EMAIL="root@wmt-os.org"

export PROFILE="${PROFILE:-standard}" # Image profile: standard | desktop
export XZ_LEVEL="${XZ_LEVEL:-9}" # Image compression level: xz 0-9[e]
export IMG_SIZE="${IMG_SIZE:-3500}" # Image size in MB

EXTRA_PACKAGES=(
	cloud-guest-utils
	console-setup
	debian-archive-keyring
	dropbear
	fastfetch
	firmware-mediatek
	htop
	network-manager
	rsync
	screen
	sudo
	wireless-regdb
	wpasupplicant
)

DESKTOP_PACKAGES=(
	alsa-utils
	dbus-user-session
	dillo
	fonts-wqy-microhei
	fox1.6-utils
	gnome-icon-theme
	gogglesmm
	icewm
	netsurf-gtk
	polkitd
	udevil
	xbacklight
	xdm
	xfe
	xorg
	xserver-xorg-video-wmt
	xterm
)
