# Debian for Wondermedia 8505 Netbooks
This project delivers a complete Debian build for WM8505-powered netbooks. It has been specifically built for the Sylvania SYNET07526, though it should work on similar devices. It utilizes the `config.armel_none_marvell` configuration from Debian's [linux-config-6.1](https://packages.debian.org/bookworm/armel/linux-config-6.1) armel package, adapting it to the WM8505. This ensures that all standard kernel modules are compiled, offering plug-and-play support for USB Wi-Fi, ethernet, sound cards, and other devices.

## Credits
This work is largely based on [wh0's bookconfig](https://github.com/wh0/bookconfig). The kernel is downloaded directly from their repository, which itself is a rebase of the abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project. It goes without saying this would not have been possible without their work.

## Build Details
- **Packages:** The `multistrap.conf` file integrates all of Debian's standard system utilities typically selected by `tasksel`. Additional packages are included to provide Wi-Fi support, along with `openssh-server`, `sudo`, and `htop`.
- **First-Boot Setup:** The initial setup takes approximately 30 minutes, where you will be prompted to configure the hostname, timezone, and create a user account. This user is added to the `sudo` group since a root password is not configured.
- **Swap File:** A 256 MB swap file is created and activated at first boot. It is handled by `var-swapfile.swap`.
- **Wi-Fi Configuration:** The Wi-Fi adapter is enabled on boot by default using `wlan-gpio.service`. You can configure your network via `nmtui`.
- **Display Brightness:** Brightness is managed by `/etc/udev/rules.d/10-display.rules` and defaults to full brightness (value 128). Changes require file modification and a reboot. The kernel also now defaults to 128 (rather than 16), meaning the screen will be full brightness during startup.
- **Audio Support:** Built-in audio is currently not working.

## Pre-compiled Builds
Pre-compiled builds are available on the Releases page. Download the `boot.zip` and `rootfs.tar.gz` files for the current build, then proceed to the "Using the Build" section below.

## Build Procedure
The build requires a Debian-based system due to its use of `multistrap`. You must also run as root. Follow these steps:

1. Clone this repository.
2. Install the necessary packages: `bc binfmt-support build-essential debian-archive-keyring gcc-arm-linux-gnueabi libncurses5-dev libssl-dev multistrap u-boot-tools zip`
3. Run `build.sh` to start the build process. The resulting `boot.zip` and `rootfs.tar.gz` files will be created in the parent directory.

## Using the Build
You will need an SD card (tested up to 32 GB) with two partitions:

1. A 32 MB FAT32 partition
2. An EXT4 partition using the remaining space

### Extraction Steps
As root:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sd*1 boot/
mount /dev/sd*2 rootfs/
unzip /path/to/boot.zip -d boot/
tar xvzf /path/to/rootfs.tar.gz -C rootfs/
umount boot/ rootfs/
eject /dev/sd*
```

### Partition Example
![GParted partition example screenshot](https://i.imgur.com/gRDMqo1.png)
