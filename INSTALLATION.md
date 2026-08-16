# Installing WMT OS

WMT OS runs entirely from an SD card, leaving the netbook's internal Windows CE installation untouched. To get started, you just need an SD card (between 4GB and 64GB; 8GB+ recommended) and a computer to flash it.

## 1. Download an image

The newest build of each profile is always available below. All releases can also be browsed directly at [releases.wmt-os.org](https://releases.wmt-os.org/).

- **[wmt-os-standard.img.xz](https://releases.wmt-os.org/latest/wmt-os-standard.img.xz)** ([sha256](https://releases.wmt-os.org/latest/wmt-os-standard.img.xz.sha256)): A minimal console system with Wi-Fi, SSH, and all standard system utilities.
- **[wmt-os-desktop.img.xz](https://releases.wmt-os.org/latest/wmt-os-desktop.img.xz)** ([sha256](https://releases.wmt-os.org/latest/wmt-os-desktop.img.xz.sha256)): Everything in standard, plus the 2D-accelerated X.org driver, IceWM, the Dillo and NetSurf web browsers, Xfe file manager, Goggles Music Manager, a text editor, calculator, image viewer, USB drive automounting, and volume/brightness hotkeys.

To verify your download, place the checksum file next to the image and run:

```bash
sha256sum -c wmt-os-standard.img.xz.sha256
```

## 2. Flash the SD card

Use your preferred imaging tool to write the OS to your card:

- **Raspberry Pi Imager:**
  - Click "CHOOSE OS", select "Use custom", and open the downloaded image.
  - Click "CHOOSE STORAGE" and select your SD card.
  - Click "NEXT". Choose "NO" for applying OS customizations, then "YES" to start flashing.
- **Command Line (`dd`):**
  - Decompress the image:
    ```bash
    xz -d /path/to/wmt-os-<profile>-<stamp>.img.xz
    ```
  - Flash the image (replace `/dev/sdX` with your SD card):
    ```bash
    sudo dd if=wmt-os-<profile>-<stamp>.img of=/dev/sdX bs=1M conv=fsync
    ```
  - Eject the drive:
    ```bash
    sudo eject /dev/sdX
    ```

## 3. Pre-configure

WMT OS runs completely unattended on first boot. It reads your desired hostname, timezone, keymap, username, and account passwords from a `setup.ini` file on the card's FAT boot partition.

You can generate this file using a visual setup wizard included directly on the flashed SD card. Choose one of these three ways to run it:

- **On the netbook (from Windows CE):**
  1. Power on the netbook into Windows CE, then insert the flashed SD card.
  2. Open "My Computer", then "Storage Card".
  3. Double-click `setup`.
  4. Fill out the form and click Save to generate your `setup.ini` file.
  5. Shut down, then power back on. The netbook will boot into WMT OS.
     ![Setup wizard running on Windows CE](https://wmt-os.org/assets/setup-wince.png)
- **On a Windows PC:** Open the card and run `setup.cmd`. The same form opens and saves `setup.ini` in place.
- **On Linux or macOS:** Open `setup-web.html` in a web browser, fill out the form, and click Save. Copy the downloaded `setup.ini` to the root of the card's boot partition.

If you skip configuration, the system falls back to these default credentials:

| Setting       | Default    |
| :------------ | :--------- |
| Hostname      | `wmt-os`   |
| Root password | `root`     |
| Username      | `wmt-user` |
| User password | `wmt-user` |
| Timezone      | UTC        |
| Keymap        | `us`       |

The default user account is a sudoer. `setup.ini` is read once on first boot and then shredded since it holds plaintext passwords. If you boot using the defaults, be sure to change both passwords after logging in.

## 4. First boot

With the card inserted, power on the netbook. It will boot WMT OS automatically.

The initial boot takes several minutes. During this time, it applies your configuration, expands the root filesystem to fill the rest of the SD card, creates a 256 MB swap file, and generates SSH host keys. This setup runs only once.

---

Your netbook is now running WMT OS. See [USAGE](USAGE.md) for using and maintaining your system.
