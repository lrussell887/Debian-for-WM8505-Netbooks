# Debian for Wondermedia WM8505 Netbooks
This project delivers a complete, modern Debian build for WM8505-powered netbooks. It has been specifically tested for the Sylvania SYNET07526, the sub-$100 netbook [sold by CVS in 2011](https://www.yourwarrantyisvoid.com/2011/01/08/hardware-pr0n-sylvania-netbook-from-cvs/). It has been found to work on other generic WM8505 netbooks, and should work on the WM8650 with some adjustments*.

The [kernel](https://github.com/lrussell887/linux-vtwm) used is a Linux 6.1 rebase of [linux-vtwm](https://github.com/linux-wmt/linux-vtwm), a repository with patches for VIA/Wondermedia SoCs. The build script automatically rebases further to the latest 6.1.x release from upstream, fetches the [linux-config-6.1](https://packages.debian.org/bookworm/armel/linux-config-6.1) package from Debian, and adapts the most similar target, `config.armel_none_marvell`, to be compatible with the netbook using a combination of options from the `seed` and the kernel's defconfig. `multistrap` is used to build the Debian root filesystem,  and `systemd-nspawn` to configure it.

All standard system utilities and kernel modules are included, providing the functionality you would expect from a stock Debian system. USB sound cards, Wi-Fi adapters, and Ethernet adapters have been tested to work normally.

![Netbook running Debian with FVWM](https://i.imgur.com/3693XlO.png)

<sub>\* I have been unable to test the WM8650 since I only have WM8505 devices. The kernel options should be the same, so I would expect it to work after changing `wm8505-ref.dtb` to `wm8650-mid.dts` in the build script. The `wm8505fb.patch` would likely need to be reverted as well since WM8650+ uses a [different pixel format](https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ), which can be done by deleting the file from the `patch` folder. Please reach out if you run into issues or are able to get this working.</sub>

## Credits
Special thanks to wh0's [bookconfig](https://github.com/wh0/bookconfig) for providing a Linux 6.1 rebase of the abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project. This would not have been possible without them.

## Project Details
- **Packages:** `multistrap.conf` integrates all of Debian's standard system utilities by explicitly listing priority `important` and `standard` packages. It also includes additional packages for Wi-Fi, SSH, and other utilities.
- **Patches:** `wm8505fb.patch` applies the correct default contrast value for the WM8505.
- **Systemd:**
    - **expand-rootfs.service** - Expands the root filesystem using `growpart` and `resize2fs` on first boot.
    - **gen-dropbear-keys.service** - Generates Dropbear SSH host keys on first boot.
    - **wlan-gpio.service** -  Uses `gpioset` to connect/disconnect the built-in USB Wi-Fi adapter.
    - **systemd-firstboot.service.d/override.conf** - Drop-in file to override prompts for `systemd-firstboot`.
- **Udev:** `10-display.rules` allows control of display contrast in the `wm8505-fb` driver. The default of 128 is the max value. A reboot is required to change this setting.
- **Fstab:** Mounts the swap file `/var/swapfile`.

## Build Details
- **First Boot:** The first boot process takes about 5 minutes. You will be asked to configure your timezone, set a hostname, and create a root password.
- **Storage:** The root filesystem is expanded to fit the SD card on first boot.
- **Memory:** A 256 MB swap file is included in the disk image and is mounted by `/etc/fstab` on boot.
- **Wi-Fi:** The built-in Wi-Fi adapter is controlled by GPIO and is enabled on boot. You can configure your network via `nmtui`. Ensure your network allows [802.11g](https://en.wikipedia.org/wiki/IEEE_802.11g-2003) clients.
- **SSH:** [Dropbear SSH](https://matt.ucc.asn.au/dropbear/dropbear.html) is included, and keys are generated on first boot.

## Limitations
- **Display:** The display backlight is always on and cannot be controlled.
- **Graphics:** Graphics acceleration is not available. Everything is software-rendered, making screen redraws very expensive. Video playback and most games are not feasible.
- **Audio:** Built-in audio is non-functional as kernel support for the codec is unavailable.
- **Battery:** Battery state monitoring is not possible.
- **Storage:** Internal NAND/serial flash is inaccessible.
- **Performance:** The WM8505 is very slow. It runs at 300 MHz<sup>?</sup> with a single core, lacking floating-point acceleration, speculative execution, and essentially all features typical of a modern CPU. Running Debian on such a device is more of a novelty than anything.

Most of these limitations are due to using the open-source [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) kernel rather than utilizing the modifications made by VIA. I would expect projectgus's [kernel_wm8505](https://github.com/projectgus/kernel_wm8505) repo to run better, particularly when it comes to graphics, though it is an ancient Android-based kernel stuck at 2.6.29. If someone more experienced than me wants to attempt to apply VIA's patches to a newer kernel, you'd definitely get my attention.

## Building
Building requires a Debian or Ubuntu-based system due to its use of `multistrap`. Follow these steps:
1. Install the necessary packages:
    ```bash
    sudo apt install bc binfmt-support bison build-essential curl debian-archive-keyring dosfstools e2fsprogs flex gcc-arm-linux-gnueabi git jq libssl-dev lynx multistrap parted pigz qemu-user-static systemd-container u-boot-tools zerofree
    ```
2. Clone this repository:
    ```bash
    git clone https://github.com/lrussell887/Debian-for-WM8505-Netbooks.git
    ```
3. Run `build.sh` (needs root privileges):
    ```bash
    sudo ./build.sh
    ```
The resulting build files (`disk_6.1.X.img.gz` and `upgrade_6.1.X.tar.gz`) are placed in the `build` directory.

## Releases
Pre-compiled builds are available on the Releases page.
- **disk_6.1.X.img.gz** - Full disk image containing `boot` and `rootfs` partitions. Used for new installations.
- **upgrade_6.1.X.tar.gz** - Tarball containing updated `boot` files and kernel modules to be placed into `rootfs`. Used for upgrading an existing installation.

## Installing
For setting up a new Debian installation.

**Requirements:**
- An SD card between 4GB and 32GB.
- A copy of `disk_6.1.X.img.gz`.
- An imaging tool like [balenaEtcher](https://www.balena.io/etcher) (recommended) or `dd`.

**Installation Steps:**
1. **Image the SD Card:**
    - **With balenaEtcher:** Use balenaEtcher to flash `disk_6.1.X.img.gz` to your SD card. It will decompress the image for you.
    - **With `dd`:**
        - Decompress the image with:
            ```bash
            gzip -d /path/to/disk_6.1.X.img.gz
            ```
        - Identify your SD card device (e.g., `/dev/sdX`), and run:
            ```bash
            sudo dd if=/path/to/disk_6.1.X.img of=/dev/sdX bs=1M status=progress
            ```
        - Then eject the SD card using:
            ```bash
            sudo eject /dev/sdX
            ```
2. **Insert the SD Card:** Place the imaged SD card into your netbook.
3. **Boot the Netbook:** Turn on your netbook. It will boot from the SD card automatically.

## Upgrading
For upgrading an existing Debian installation to a newer kernel.

**Requirements:**
- An SD card with an existing image.
- A copy of `upgrade_6.1.X.tar.gz`.
- A Linux computer.

**Upgrade Steps:**
1. Mount the `boot` and `rootfs` partitions. Identify your SD card device (e.g., `/dev/sdX`), and run:
    ```bash
    mkdir boot rootfs
    sudo mount /dev/sdX1 boot
    sudo mount /dev/sdX2 rootfs
    ```
2. Update the `boot` partition:
    ```bash
    sudo rm -rf boot/*
    sudo tar -xzvf /path/to/upgrade_6.1.X.tar.gz -C boot --strip-components=1 boot
    ```
3. Update the `rootfs` partition:
    ```bash
    sudo rm -rf rootfs/lib/modules/*
    sudo tar -xzvf /path/to/upgrade_6.1.X.tar.gz -C rootfs --strip-components=1 --skip-old-files rootfs
    ```
4. Eject the SD card:
    ```bash
    sudo eject /dev/sdX
    ```
