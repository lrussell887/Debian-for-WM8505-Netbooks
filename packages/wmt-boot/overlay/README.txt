WMT OS
======

FIRST-TIME SETUP
----------------
Before its first boot, WMT OS requires a hostname, timezone, keymap,
username, and account passwords.

  [ Windows or Windows CE ]
  Run setup.cmd, fill out the form, and click Save to generate your setup.ini
  file. It is saved to the card automatically.

  [ Linux or macOS ]
  Open setup-web.html in a web browser, fill out the form, and click Save. Copy
  the downloaded setup.ini file to this directory.

Boot the device and WMT OS will finish the setup automatically.


ROLL BACK A KERNEL
------------------
If a kernel update causes issues, you can easily revert to the previous kernel.

  [ Windows or Windows CE ]
  Run rollback.cmd.

  [ Linux or macOS ]
  Open a terminal and run:
    sh /path/to/rollback.sh

The script displays the current and previous kernels and prompts you to switch
between them. You can re-run the script to switch back.
