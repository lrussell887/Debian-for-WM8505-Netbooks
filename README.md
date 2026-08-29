# WMT OS

This repository is the build system for WMT OS, a modern Linux distribution for netbooks built on the WonderMedia WM8505 SoC, based on Debian 13 (Trixie). Downloads, the installation guide, the handbook, and the changelog are at [wmt-os.org](https://wmt-os.org/).

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
