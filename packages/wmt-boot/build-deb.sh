#!/bin/bash
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
. "$(dirname "$0")/../../scripts/lib.sh"

SRC="$BASE_DIR/packages/wmt-boot"
DEBS="$BUILD_DIR/debs"
STAMP=${STAMP:-$(date +%s)}
# Hash the whole directory (recipe included) so any change re-keys the version
HASH=$(find "$SRC" -type f | LC_ALL=C sort | xargs cat | sha256sum | cut -c1-12)
VERSION="$STAMP+$HASH"

log INFO "Building wmt-boot ($VERSION)"
mkdir -p "$DEBS"
staging=$(mktemp -d)
install -Dm755 "$SRC/deploy" "$staging/usr/sbin/wmt-deploy-boot"
install -Dm755 "$SRC/kernel-postinst" "$staging/etc/kernel/postinst.d/zz-wmt-boot"
install -Dm755 "$SRC/kernel-postrm" "$staging/etc/kernel/postrm.d/zz-wmt-boot"
install -Dm644 "$SRC/uboot.cmd" "$staging/usr/share/wmt-boot/uboot.cmd"
install -Dm644 "$SRC/default" "$staging/etc/default/wmt-boot"
for f in "$SRC"/overlay/*; do
	install -Dm644 "$f" "$staging/usr/share/wmt-boot/overlay/${f##*/}"
done
install -Dm755 "$SRC/postinst" "$staging/DEBIAN/postinst"
install -Dm644 "$SRC/triggers" "$staging/DEBIAN/triggers"
echo /etc/default/wmt-boot > "$staging/DEBIAN/conffiles"
cat > "$staging/DEBIAN/control" <<EOF
Package: wmt-boot
Version: $VERSION
Architecture: all
Maintainer: $BUILDER_NAME <$BUILDER_EMAIL>
Section: kernel
Priority: optional
Depends: tzdata, u-boot-tools, xkb-data
Description: WonderMedia WM8505 boot integration
 Builds each kernel's U-Boot boot image, keeping the previous one as a rollback.
EOF
dpkg-deb --root-owner-group --build "$staging" "$DEBS/wmt-boot_${VERSION}_all.deb" >/dev/null
rm -rf "$staging"
