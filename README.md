# WMT OS

WMT OS is a modern Linux distribution for devices powered by the WonderMedia WM8505 SoC, based on Debian 13 (Trixie).

Development is focused on the Sylvania Netbook, sold for $99 [by CVS in late 2010](https://www.informationweek.com/it-leadership/cvs-offers-99-sylvania-netbook) running Windows CE 6.0. Equipped with a 300 MHz single-core [ARM926EJ-S](https://en.wikipedia.org/wiki/ARM9#ARM9E-S_and_ARM9EJ-S) SoC (sharing the same 2001 CPU architecture as the Nintendo Wii... well, its coprocessor), 128 MB of RAM, and an 800x480 display, it was considered e-waste even when it was first released. Naturally, that makes it an excellent candidate for a modern Linux distribution today.

![Netbook running WMT OS](https://wmt-os.org/assets/netbook.png)

## Getting Started

Flash an image below to an SD card and the netbook boots straight into WMT OS. A setup wizard on the card's boot partition configures the system prior to boot. See [INSTALLATION](INSTALLATION.md) for the full setup guide. Once installed, see [USAGE](USAGE.md) for using and maintaining your system.

- **[wmt-os-standard.img.xz](https://releases.wmt-os.org/latest/wmt-os-standard.img.xz)** ([sha256](https://releases.wmt-os.org/latest/wmt-os-standard.img.xz.sha256)): Console image
- **[wmt-os-desktop.img.xz](https://releases.wmt-os.org/latest/wmt-os-desktop.img.xz)** ([sha256](https://releases.wmt-os.org/latest/wmt-os-desktop.img.xz.sha256)): Desktop image (recommended)

## Hardware Support

Known working models, with other WM8505 netbooks likely compatible:

- Sylvania Netbook (SYNET07526 / SYNET7WID), 7" 800x480, VT1613 or VT1612A codec
- JAY-tech 9901, 7" 800x480, VT1613 codec
- EPC-1026, 10" 1024x600, WM9715L codec

| Component                                            | Status | Notes                                           |
| :--------------------------------------------------- | :----: | :---------------------------------------------- |
| **Display**                                          |   🟢   | Built-in LCD panel, resolution auto-detected    |
| **Backlight**                                        |   🟢   | PWM brightness control                          |
| **Graphics Acceleration**                            |        |                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&#8627; _Kernel_             |   🟢   | DRM/KMS driver with 2D and console acceleration |
| &nbsp;&nbsp;&nbsp;&nbsp;&#8627; _Userspace_          |   🟢   | 2D-accelerated X.org video driver with VSync    |
| **Video Acceleration**                               |        |                                                 |
| &nbsp;&nbsp;&nbsp;&nbsp;&#8627; _JPEG/MJPEG Decoder_ |   🔵   | Dedicated decode engine for video playback      |
| &nbsp;&nbsp;&nbsp;&nbsp;&#8627; _Video Scaler_       |   🔵   | Hardware scaling engine                         |
| **Built-in Audio**                                   |   🟢   | Headphone and speaker output                    |
| **Keyboard & Touchpad**                              |   🟢   | Built-in PS/2 controller                        |
| **Internal Storage**                                 |   🔴   | NAND flash controller inaccessible              |
| **SD Card**                                          |   🟢   | Built-in SD/MMC controller                      |
| **Wi-Fi**                                            |   🟢   | Internal USB adapter                            |
| **USB Peripherals**                                  |   🟢   | Keyboards, mice, audio, storage, and networking |
| **Battery Monitoring**                               |   🟢   | Self-calibrating voltage-based estimation\*     |

_(Legend: 🟢 Supported | 🟡 Partial | 🔵 Planned | 🔴 Unsupported)_

_\* Supported on the ADC-less VT1613 and VT1612A boards. WM9715L boards currently are not._

## Kernel

This project is powered by the actively maintained [linux-wmt](https://github.com/wmt-os/linux-wmt) kernel fork, currently tracking the `6.12.y` LTS branch. Active development continues to modernize the SoC's hardware support, with recent work bringing new DRM/KMS, DMA engine, ASoC, CCF, Serio, and battery drivers to the platform.

## Package Repository

Every image is preconfigured with the signed WMT OS APT repository at [apt.wmt-os.org](https://apt.wmt-os.org/), pinned above Debian. It delivers the kernel and other packages; the recipes and publishers live in [wmt-os-dist](https://github.com/wmt-os/wmt-os-dist). Devices stay current through APT updates.

## Releases

Images are dated builds named `wmt-os-<profile>-<stamp>.img.xz`, published at [releases.wmt-os.org](https://releases.wmt-os.org/) with a checksum alongside. The newest image of each profile is always available at its stable [latest](https://releases.wmt-os.org/latest/) link.

## Repository Contents

- **`Makefile`**: The build entry point; run `make` to list the available targets.
- **`config.sh`**: Build settings: cross toolchain, kernel repo and branch, image options, and package sets.
- **`kernel-seed.config`**: Kernel options that "seed" support for the WM8505, merged over Debian's default `armel_none_rpi` config.
- **`scripts/`**: The build pipeline, split into small single-purpose steps (`mk-config`, `mk-debs`, `mk-rootfs`, `mk-image`), plus the kernel repo helpers.
- **`packages/`**: Debian package sources, each built by its own `build-deb.sh`: `wmt-boot/` (U-Boot boot images, the A/B rollback slot, and the boot partition's user-facing files), `wmt-os-base/` (distribution identity and repository trust), and `wmt-platform-wm8505/` (hardware platform configuration).
- **`bootstrap/`**: Inputs applied while the rootfs bootstraps: `hooks-base.sh` (in-chroot configuration) and the build-time APT priorities.
- **`overlays/`**: Trees copied verbatim over the root filesystem, including the first-boot setup service.

## Building from Source

Building requires a Debian or Ubuntu host (for `mmdebstrap`). Images resolve packages from Debian and the WMT OS repository, and kernels built locally always take precedence over published ones.

1. Clone this repository and navigate to its directory:
   ```bash
   git clone https://github.com/wmt-os/wmt-os.git && cd wmt-os/
   ```
2. Install the host build dependencies:
   ```bash
   sudo scripts/install-deps.sh
   # OR
   make deps
   ```
3. Build the disk image:
   ```bash
   make standard
   ```
The build invokes `sudo` for the steps that need root (the rootfs and image). The resulting `wmt-os-standard-<stamp>.img.xz` is placed in the `build/` directory. Run `make` on its own to list every target, including `desktop`, `all`, the individual stages, and cleanup.

## Related Repositories

- **[linux-wmt](https://github.com/wmt-os/linux-wmt)**: The kernel fork powering the platform.
- **[xf86-video-wmt](https://github.com/wmt-os/xf86-video-wmt)**: The 2D-accelerated X.org video driver.
- **[wmt-os-dist](https://github.com/wmt-os/wmt-os-dist)**: The publishers and package recipes.

## Credits

Special thanks to the following projects:

- **[linux-vtwm](https://github.com/linux-wmt/linux-vtwm)**: For pioneering mainline support for WonderMedia SoCs, including the WM8505.
- **[projectgus/kernel_wm8505](https://github.com/projectgus/kernel_wm8505)**: For archiving VIA's original BSP patches, which served as an invaluable reference throughout this modernization effort.

---

_Disclaimer: WMT OS is an independent project, not affiliated with Debian, WonderMedia Technologies, or VIA Technologies. Debian is a registered trademark owned by Software in the Public Interest, Inc._
