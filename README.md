# Debian for Wondermedia WM8505 Netbooks
This project delivers a complete, modern Debian build for WM8505-powered netbooks. It has been specifically tested for the Sylvania SYNET07526, the sub-$100 netbook [peddled by CVS in 2011](https://www.yourwarrantyisvoid.com/2011/01/08/hardware-pr0n-sylvania-netbook-from-cvs/). It should work on other generic WM8505 netbooks, as well as the WM8650 with some adjustments*.

![Netbook running Debian](https://i.imgur.com/73nZJa5.png)

The [kernel](https://github.com/lrussell887/linux-vtwm) used is a rebase of linux-vtwm, a repository with patches for VIA VT8500 and Wondermedia WM8xxx SoCs. The build script automatically rebases it further to the latest 6.1.x release from upstream, fetches the [linux-config-6.1](https://packages.debian.org/bookworm/armel/linux-config-6.1) package from Debian, and adapts the most similar target, `config.armel_none_marvell`, to be compatible with the netbook using a combination of options from the `seed` and the kernel's defconfig. `multistrap` is used to build the Debian root filesystem, and includes all standard system utilities.

This ensures you have an up-to-date kernel with all the standard kernel modules and packages you would expect from a stock Debian system. USB sound cards, Wi-Fi cards, and network adapters all work as expected.

<sub>\* I have been unable to test the WM8650 since I only have WM8505 devices. The kernel options should be the same, so I would expect it to work after changing `wm8505-ref.dtb` to `wm8650-mid.dts` in the build script. The `wm8505fb.patch` would likely need to be reverted as well since WM8650+ uses a [different pixel format](https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ), which can be done by deleting the file from the `patch` folder. Wi-Fi is also handled by GPIO in the `wlan-gpio.service`, which may differ between devices. If you are having trouble, please reach out as I may be able to assist.</sub>

## Credits
Special thanks to [wh0's bookconfig](https://github.com/wh0/bookconfig) for providing a kernel 6.1.x rebase of the abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project. This project would not have been possible without them.

## Project Details
- **Packages:** The `multistrap.conf` file integrates all of Debian's standard system utilities by explicitly listing priority `important` and `standard` packages. Additional packages are included to provide Wi-Fi support, along with `openssh-server`, `sudo`, and `htop`.
- **First Boot:** It takes approximately 25 minutes to finish setting up packages on first boot. You will be prompted to set a hostname, create a user account, and configure your timezone. The user is added to the `sudo` group since a root password is not configured.
- **Memory:** A 256 MB swap file is created and activated at first boot. It is handled by `var-swapfile.swap`.
- **Wi-Fi:** The built-in Wi-Fi adapter is controlled by GPIO, and is enabled on boot by default using `wlan-gpio.service`. You can configure your network via `nmtui`. These Wi-Fi adapters are usually 802.11g, so ensure your network allows this.
- **Display:** Contrast is managed by `/etc/udev/rules.d/10-display.rules` and defaults to full brightness (value 128). Changes require a reboot. The kernel has been patched to allow full brightness during startup.

## Limitations
- **Display:** The display backlight is always on and cannot be controlled.
- **Graphics:** Graphics acceleration is not available. Everything is software-rendered, making screen redraws very expensive. Video playback and most games are not feasible.
- **Audio:** Built-in audio is non-functional as kernel support for the codec is unavailable.
- **Battery:** Battery state monitoring is not possible.
- **Storage:** Internal NAND/serial flash is inaccessible.
- **Performance:** The WM8505 is very slow. It runs at 300 MHz with a single core, lacking floating-point acceleration, speculative execution, and essentially all features typical of a modern CPU. Running Debian on such a device is more of a novelty than anything.

Most of these limitations are due to using the open-source [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) kernel rather than utilizing the modifications made by VIA. I would expect projectgus's [kernel_wm8505](https://github.com/projectgus/kernel_wm8505) repo to run better, particularly when it comes to graphics, though it is an ancient Android-based kernel stuck at 2.6.29. If someone more experienced than me wants to attempt to apply VIA's patches to a newer kernel, you'd definitely get my attention.

## Building
Building requires a Debian or Ubuntu-based system due to its use of `multistrap`. Follow these steps:
1. Clone this repository.
2. Install the necessary packages: `bc binfmt-support bison build-essential curl debian-archive-keyring flex gcc-arm-linux-gnueabi git jq libssl-dev lynx multistrap pigz u-boot-tools zip`
3. Run `build.sh` as root or with `sudo` to start the build process. The resulting build files (`boot.zip`, `rootfs.tar.gz`, `modules.tar.gz`) are placed in the `build` directory.

## Releases
Pre-compiled builds are available on the Releases page.
- **boot.zip** - Contains the U-Boot script image and kernel image.
- **rootfs.tar.gz** - Contains the complete Debian root filesystem and kernel modules — used for a new installation.
- **modules.tar.gz** - Contains only the kernel modules — used in conjunction with `boot.zip` for upgrading.

## Using the Build
To use a build, you will need to create an SD card from a Linux machine. The SD card must be between 4 GB and 32 GB in size. These builds are made to boot and run from the SD card on the netbook.
### 1. Partitioning
Partition your SD card as follows:
1. A 32 MB FAT32 `boot` partition
2. An EXT4 `rootfs` partition using the remaining space

It is recommended to use an MBR partition table.

![GParted partition example screenshot](https://i.imgur.com/gRDMqo1.png)

### 2. Extraction
After partitioning your SD card, you need to extract `boot.zip` and `rootfs.tar.gz` to the appropriate partitions. It is important to extract as root to preserve the permissions of the root filesystem.

Do the following as root, substituting `/dev/sdX` with the correct device:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sdX1 boot
mount /dev/sdX2 rootfs
unzip /path/to/boot.zip -d boot
tar -xvzf /path/to/rootfs.tar.gz -C rootfs
eject /dev/sdX
```

### 3. Booting
Insert the SD card into your netbook, then power it on. It will boot from the SD card automatically.

## Upgrading
To update an existing Debian system to a newer kernel, you need to:
1. Obtain an updated copy of `boot.zip` and `modules.tar.gz`.
2. Replace the contents of the `boot` partition.
3. Install the new kernel modules into the `rootfs`.
4. Ideally remove the old kernel modules to free up space.

The following steps assume you are using another computer.

Do the following as root, substituting `/dev/sdX` with the correct device:
```bash
cd /mnt
mkdir boot rootfs
mount /dev/sdX1 boot
mount /dev/sdX2 rootfs
rm -rf boot/*
unzip /path/to/boot.zip -d boot
rm -rf rootfs/lib/modules/*
tar --skip-old-files -xvzf /path/to/modules.tar.gz -C rootfs
eject /dev/sdX
```
