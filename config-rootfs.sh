#!/bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
export LC_ALL=C LANGUAGE=C LANG=C

/var/lib/dpkg/info/base-passwd.preinst install
dpkg --configure -a

fallocate -l 256M /var/swapfile
chmod 600 /var/swapfile
mkswap /var/swapfile

update-alternatives --set regulatory.db /lib/firmware/regulatory.db-upstream

rm /etc/dropbear/dropbear_*_host_key
rm /etc/machine-id

exit 0
