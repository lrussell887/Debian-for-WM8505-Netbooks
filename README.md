# Debian for Wondermedia WM8505 Netbooks
This project delivers a complete, modern Debian build for WM8505-powered netbooks. It has been specifically tested for the Sylvania SYNET07526, the sub-$100 netbook [peddled by CVS in 2011](https://www.yourwarrantyisvoid.com/2011/01/08/hardware-pr0n-sylvania-netbook-from-cvs/). It should work on other generic WM8505 netbooks, along with WM8650 with some minor adjustments*.

![Netbook running Debian](https://i.imgur.com/73nZJa5.png)

The [kernel](https://github.com/lrussell887/linux-vtwm) used is a rebase of linux-vtwm, a repository with patches for VIA VT8500 and Wondermedia WM8xxx SoCs. The build script automatically rebases it further to the latest 6.1.x release from upstream, fetches the [linux-config-6.1](https://packages.debian.org/bookworm/armel/linux-config-6.1) package from Debian, and adapts the most similar target, `config.armel_none_marvell`, to be compatible with the netbook using a combination of options from the `seed` and the kernel's defconfig. `multistrap` is used to build the Debian root filesystem, and includes all standard system utilities.

This ensures you have an up-to-date kernel with all the standard kernel modules and packages you would expect from a stock Debian system. USB sound cards, Wi-Fi cards, and network adapters all work as expected.

\* I have been unable to test the WM8650 since I only have WM8505 devices. The kernel options should be the same, so I would expect it to at least boot. The `wm8505fb.patch` would likely need to be reverted since WM8650+ uses a [different pixel format](https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ), which can be done by deleting the file from the `patch` folder and building normally. Wi-Fi is also handled by GPIO in the `wlan-gpio.service`, which may differ between devices. If you are having trouble with one of these devices, please reach out to me as I may be able to assist.

## Credits
Special thanks to [wh0's bookconfig](https://github.com/wh0/bookconfig) for providing a kernel 6.1.x rebase of the abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project. It goes without saying this would not have been possible without them.

## Project Details
- **Packages:** The `multistrap.conf` file integrates all of Debian's standard system utilities by explicitly listing priority `important` and `standard` packages. Additional packages are included to provide Wi-Fi support, along with `openssh-server`, `sudo`, and `htop`.
- **First Boot:** It takes approximately 25 minutes to finish setting up packages on first boot. You will be prompted to set a hostname, configure your timezone, and create a user account. This user is added to the `sudo` group, as a root password is not configured.
- **Memory:** A 256 MB swap file is created and activated at first boot. It is handled by `var-swapfile.swap`.
- **Wi-Fi:** The Wi-Fi adapter is controlled by GPIO, and is enabled on boot by default using `wlan-gpio.service`. You can configure your network via `nmtui`.
- **Display:** Contrast is managed by `/etc/udev/rules.d/10-display.rules` and defaults to full brightness (value 128). Changes require a reboot. The kernel has been patched to allow full brightness during startup. The display backlight cannot be controlled; it is always on.
- **Audio:** The built-in audio does not function.
- **Battery:** The battery state cannot be monitored.
- **Performance:** The WM8505 is... slow. It runs at 300 MHz, has a single core, and has no floating-point acceleration. There is no graphics acceleration either, meaning any graphics are software-rendered. Temper your expectations.

## Build Procedure
Building requires a Debian or Ubuntu-based system due to its use of `multistrap`. Follow these steps:
1. Clone this repository.
2. Install the necessary packages: `bc binfmt-support bison build-essential curl debian-archive-keyring flex gcc-arm-linux-gnueabi git libssl-dev lynx multistrap u-boot-tools zip`
3. Run `build.sh` as root or with `sudo` to start the build process. The resulting build files (`boot.zip`, `rootfs.tar.gz`, `modules.tar.gz`) are placed in the `build` directory.

## Releases
Precompiled builds are available on the Releases page. Download the files for the current build, then proceed to the "Using the Build" section below.

## Using the Build
### Partitioning
You will need an SD card (up to 32 GB) with two partitions:
1. A 32 MB FAT32 partition
2. An EXT4 partition using the remaining space

![GParted partition example screenshot](https://i.imgur.com/gRDMqo1.png)

### Extraction
After partitioning your SD card, do the following as root, substituting `/dev/sdX` with the correct device:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sdX1 boot
mount /dev/sdX2 rootfs
unzip /path/to/boot.zip -d boot
tar xvzf /path/to/rootfs.tar.gz -C rootfs
umount boot rootfs && eject /dev/sdX
```

### Booting
Insert the SD card into your netbook, then power it on. It will boot from the SD card automatically.

## Upgrading
To update an existing Debian system to a newer kernel, you need to replace the contents of the `boot` partition and install the new kernel modules into the `rootfs`. After obtaining an updated copy of `boot.zip` and `modules.tar.gz`, do the following as root, substituting `/dev/sdX` with the correct device:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sdX1 boot
mount /dev/sdX2 rootfs
rm -rf boot/*
unzip /path/to/boot.zip -d boot
rm -rf rootfs/lib/modules/*
tar --skip-old-files -xzvf /path/to/modules.tar.gz -C rootfs
umount boot rootfs && eject /dev/sdX
```
