#!/bin/sh
set -e

# Use upstream regulatory.db
update-alternatives --set regulatory.db /lib/firmware/regulatory.db-upstream

# Remove SSH keys
rm /etc/dropbear/dropbear_*_host_key*

# Create swap file
dd if=/dev/zero of=/swapfile bs=1M count=256 conv=fsync
chmod 600 /swapfile
mkswap /swapfile

# Trigger systemd-firstboot
rm /etc/machine-id

exit 0
