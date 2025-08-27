# Debian for Wondermedia WM8505 Netbooks
This project delivers a complete, modern Debian 13 (Trixie) build for netbooks powered by the Wondermedia WM8505 SoC. It was specifically tested on the Sylvania SYNET07526, the sub-$100 Windows CE netbook [sold by CVS in 2011](https://www.yourwarrantyisvoid.com/2011/01/08/hardware-pr0n-sylvania-netbook-from-cvs/), but it should work on other generic WM8505 devices and should be adaptable to the WM8650*.

The kernel is a Linux 6.12 rebase of [linux-vtwm](https://github.com/lrussell887/linux-vtwm), a repository with patches for VIA/Wondermedia SoCs. The build script automates the whole process: it updates the kernel to the latest 6.12.x release from upstream, fetches the official `armel` configuration from Debian, and merges it with custom settings to create a compatible kernel. The Debian root filesystem is built with `mmdebstrap`.

All standard system utilities and kernel modules are included, providing the functionality you would expect from a stock Debian system. USB sound cards, Wi-Fi adapters, and Ethernet adapters have been tested to work normally.

![Netbook running Debian with FVWM](https://github.com/user-attachments/assets/5db36720-9a77-4f2d-a1ab-35503dd062d3)

<sub>\* I only have WM8505 devices, so I haven't been able to test this on a WM8650. To get it working, you'll need to make a few adjustments. First, edit `build.sh` and change the device tree target from `vt8500/wm8505-ref.dtb` to `vt8500/wm8650-mid.dtb`. The display settings also need to be reverted; the contrast patch is a specific fix for the WM8505, so delete `patches/wm8505fb.patch`. Then, edit `overlay/etc/udev/rules.d/10-display.rules` and change the contrast `ATTR` value from `"128"` to `"16"`. These changes are needed because the WM8650+ uses a [different pixel format](https://groups.google.com/d/msg/vt8500-wm8505-linux-kernel/-5V20yDM4jQ/sjlXNF8PAwAJ). Please reach out if you run into issues, or to let me know if you're able to get it working.</sub>

## Credits
Special thanks to wh0's [bookconfig](https://github.com/wh0/bookconfig) for maintaining the functionally abandoned [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) project, all the way up to Linux 6.1. Their work saved a massive amount of effort in getting the kernel to 6.12.

## Project Details
- **Seed:** `seed` contains the list of kernel configuration options needed to "seed" support for the WM8505, overriding options in Debian's `armel_none_rpi` config in combination with the kernel's defconfig.
- **Bootloader:**`boot.cmd` contains the commands passed to U-Boot needed to load the kernel and boot Debian.
- **Patches:** `wm8505fb.patch` applies the correct default contrast value for the WM8505 in the `wm8505-fb` driver.
- **Systemd:**
    - **expand-rootfs.service** - Expands the root filesystem using `growpart` and `resize2fs` on first boot.
    - **gen-dropbear-keys.service** - Generates Dropbear SSH host keys on first boot.
    - **update-hosts.service** - Updates /etc/hosts with the hostname on first boot.
    - **wlan-gpio.service** -  Uses `gpioset` to connect/disconnect the built-in USB Wi-Fi adapter.
    - **systemd-firstboot.service.d/override.conf** - Drop-in file to override prompts for `systemd-firstboot`.
- **Udev:** `10-display.rules` allows control of display contrast in the `wm8505-fb` driver. The default of 128 is the max value. A reboot is required to change this setting.
- **Fstab:** Mounts the swap file `/swapfile`.

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
- **Performance:** The WM8505 is very slow. It runs at 300 MHz with a single core, lacking floating-point acceleration, speculative execution, and essentially all features typical of a modern CPU. Running Debian on such a device is more of a novelty than anything.

Many of these limitations are due to using the open-source [linux-vtwm](https://github.com/linux-wmt/linux-vtwm) kernel rather than utilizing the modifications made by VIA. I would expect projectgus's [kernel_wm8505](https://github.com/projectgus/kernel_wm8505) repo to be more feature complete, particularly when it comes to graphics, though it is an ancient Android-based kernel stuck at 2.6.29. If someone more experienced than me wants to attempt to apply VIA's patches to a newer kernel, you'd definitely get my attention.

## Building
Building requires a Debian or Ubuntu-based system due to its use of `mmdebstrap`. Follow these steps:
1. Clone this repository and navigate to its directory:
    ```bash
    git clone https://github.com/lrussell887/Debian-for-WM8505-Netbooks.git
    cd Debian-for-WM8505-Netbooks/
    ```
2. Run `build.sh` (needs root privileges):
    ```bash
    sudo ./build.sh
    ```
The resulting build files (`disk-6.12.X-wm8505.img.gz` and `upgrade-6.12.X-wm8505.tar.gz`) are placed in the `build` directory.

## Releases
Pre-compiled builds are available on the Releases page.
- **disk-6.12.X-wm8505.img.gz** - Full disk image containing `boot` and `rootfs` partitions. Used for new installations.
- **upgrade-6.12.X-wm8505.tar.gz** - Tarball containing updated `boot` files and kernel modules. Used for upgrading an existing installation.

## Installing
For setting up a new Debian installation.

**Requirements:**
- An SD card between 4GB and 32GB.
- A copy of `disk-6.12.X-wm8505.img.gz`.
- An imaging tool like [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (recommended) or `dd`.

**Installation Steps:**
1. Image the SD Card:
    - With Raspberry Pi Imager:
        - **Choose OS:** Click "CHOOSE OS", select "Use custom", and open your `disk-6.12.X-wm8505.img.gz` file.
        - **Choose Storage:** Click "CHOOSE STORAGE" and select your SD card.
        - **Write:** Click "NEXT". Choose "NO" for applying OS customizations, then "YES" to start flashing.
    - With `dd`:
        - Decompress the image with:
            ```bash
            gzip -d /path/to/disk-6.12.X-wm8505.img.gz
            ```
        - Identify your SD card device (e.g., `/dev/sdX`), and run:
            ```bash
            sudo dd if=/path/to/disk-6.12.X-wm8505.img.gz of=/dev/sdX bs=1M conv=fsync
            ```
        - Then eject the SD card using:
            ```bash
            sudo eject /dev/sdX
            ```
2. Insert the imaged SD card into your netbook.
3. Turn on your netbook. It will boot from the SD card automatically.

## Upgrading
For upgrading an existing Debian installation to a newer kernel.

### Automated Upgrade (recommended):
1. Run the following on your netbook (needs root privileges):
    ```bash
    sudo bash -c "$(wget -q -O - https://raw.githubusercontent.com/lrussell887/Debian-for-WM8505-Netbooks/master/upgrade-kernel.sh)"
    ```

### Manual Upgrade:
**Requirements:**
- An SD card with an existing image.
- A copy of `upgrade-6.12.X-wm8505.tar.gz`.
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
    sudo tar -xzvf /path/to/upgrade-6.12.X-wm8505.tar.gz -C boot --strip-components=1 boot
    ```
3. Update the `rootfs` partition:
    ```bash
    sudo rm -rf rootfs/lib/modules/*
    sudo tar -xzvf /path/to/upgrade-6.12.X-wm8505.tar.gz -C rootfs --strip-components=1 --skip-old-files rootfs
    ```
4. Eject the SD card:
    ```bash
    sudo eject /dev/sdX
    ```
