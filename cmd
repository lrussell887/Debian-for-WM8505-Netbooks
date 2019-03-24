lcdinit
fatload mmc 0 0 /script/uzImage.bin
setenv bootargs root=/dev/mmcblk0p2 rw rootwait
bootm 0
