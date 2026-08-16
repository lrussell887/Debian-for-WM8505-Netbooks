# Using WMT OS

## Wi-Fi

The built-in Wi-Fi adapter is enabled on boot. You can configure your network using `nmtui` in the terminal (on the desktop, this is also found in the menu under Settings &#8594; NetworkManager). If your specific netbook shipped with the older 802.11g adapter rather than the 802.11n variant, you may need to ensure your router allows legacy [802.11g](https://en.wikipedia.org/wiki/IEEE_802.11g-2003) clients.

## Desktop hotkeys

The desktop profile ships with a few system-wide hotkeys. These can be overridden per-user by editing `~/.icewm/keys`:

| Keys                  | Action             |
| :-------------------- | :----------------- |
| Super+Up / Super+Down | Display brightness |
| Super+= / Super+-     | Volume             |
| Alt+Ctrl+T            | Terminal           |
| Alt+Ctrl+B            | Web browser        |

On these netbooks, the `Super` key corresponds to the key printed with a `Zzz` sleep icon, located exactly where the Windows key normally sits. If a window opens off-screen, hold `Alt` and drag to move it.

## Audio

Run `alsamixer` in the terminal for the full set of audio controls. The available controls vary by codec.

A USB sound card can become the default audio device by creating `~/.asoundrc` with the two lines below, using the card number shown by `aplay -l`.

```bash
defaults.pcm.card 1
defaults.ctl.card 1
```

The standard profile does not include audio utilities by default. To add them, run `sudo apt install alsa-utils`.

## Battery

These netbooks measure the battery indirectly, by timing a simple [RC circuit](https://en.wikipedia.org/wiki/RC_circuit) whose scale varies from unit to unit, so the driver calibrates itself against the one fixed voltage reference the board provides: the low-battery alarm. On a fresh install, only the charging state is reported; the charge percentage appears once the battery has drained down to the alarm for the first time, and works normally thereafter.

While plugged in, the charger's voltage masks the battery's own, so the percentage cannot update. Instead, it keeps the last reading taken on battery, if any, and shows full once charging completes. Calibration happens entirely on its own, repeats at every later alarm, and persists across reboots and kernel updates.

## Keymap

The keymap chosen during setup applies to both the console and the desktop. Layouts that cannot type Latin keep `us` alongside, switched with `Alt+Shift`. To change it later, run `sudo dpkg-reconfigure keyboard-configuration` and reboot.

## SSH

Dropbear provides the SSH server, with host keys uniquely generated on first boot. Because Dropbear lacks SFTP support, file transfers must be done using SCP or the [FISH](https://en.wikipedia.org/wiki/Files_transferred_over_shell_protocol) protocol.

## Updates

Updates ship through the WMT OS APT repository. Upgrading is exactly the same as any Debian-based system:

```bash
sudo apt update && sudo apt upgrade
```

When a new kernel installs, it builds its U-Boot files automatically and takes effect on the next reboot, keeping the previous kernel safely as a rollback.

## Kernel rollback

If a kernel update causes issues, the boot partition carries a script to easily revert to the previous kernel:

- **Windows or Windows CE:** Run `rollback.cmd`.
- **Linux or macOS:** Run `sh /path/to/rollback.sh`.

The script displays the current and previous kernels and prompts you to switch between them. Re-run it to switch back.

## Kernel command line

Extra arguments can be passed to the kernel at boot by setting `EXTRA_CMDLINE` in `/etc/default/wmt-boot`:

```bash
EXTRA_CMDLINE="loglevel=7"
```

Run `sudo wmt-deploy-boot` to apply the change, which takes effect on the next reboot. The arguments are appended to the built-in boot arguments and persist across kernel updates. Rolling back to the previous kernel also restores its original arguments.

## Display timings

The kernel reads the panel timings from the bootloader's `lcdparam` variable automatically. They can be overridden by passing `wmt_panel.lcd` on the kernel command line:

```bash
EXTRA_CMDLINE="wmt_panel.lcd=1,30000,8,800,480,48,40,40,3,29,13"
```

The fields are the version (always 1), pixel clock in kHz, color depth (unused), width, height, horizontal sync width, back porch, and front porch, then the vertical sync width, back porch, and front porch.
