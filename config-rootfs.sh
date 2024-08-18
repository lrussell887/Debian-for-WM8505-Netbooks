#!/bin/sh
set -e

export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

# Configure packages
/var/lib/dpkg/info/base-passwd.preinst install
dpkg --configure -a

# Use upstream regulatory.db
update-alternatives --set regulatory.db /lib/firmware/regulatory.db-upstream

# Remove SSH keys
rm /etc/dropbear/dropbear_*_host_key

# Trigger systemd-firstboot
rm /etc/machine-id

exit 0
