setenv LOAD_MSG Loading Kernel Image...
setenv BOOT_MSG Starting Linux...
setenv BMP_ADR 3C00000

lcdinit
fatload mmc 0 ${BMP_ADR} /logo.bmp
logo show

textout 20 20 "${KERNEL_RELEASE}" 606060
textout 20 50 "${BUILD_TIME}" 606060

textout 20 440 "${LOAD_MSG}" c0c0c0
fatload mmc 0 0 /script/uzImage.bin

textout 20 410 "${LOAD_MSG}" c0c0c0
textout 20 440 "${BOOT_MSG}" 00ff00
setenv bootargs root=/dev/mmcblk0p2 rw noinitrd console=tty1 rootwait wmt_panel.lcd=${lcdparam} ${EXTRA_CMDLINE}
bootm 0
