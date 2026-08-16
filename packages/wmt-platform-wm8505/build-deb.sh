#!/bin/bash
# Copyright (C) 2026 Logan Russell <me@lrussell.net>

set -eu
. "$(dirname "$0")/../../scripts/lib.sh"

SRC="$BASE_DIR/packages/wmt-platform-wm8505"
DEBS="$BUILD_DIR/debs"
STAMP=${STAMP:-$(date +%s)}
HASH=$(find "$SRC" -type f | LC_ALL=C sort | xargs cat | sha256sum | cut -c1-12)
VERSION="$STAMP+$HASH"

log INFO "Building wmt-platform-wm8505 ($VERSION)"
mkdir -p "$DEBS"
staging=$(mktemp -d)
install -Dm644 "$SRC/50-wm8505.conf" "$staging/etc/alsa/conf.d/50-wm8505.conf"
install -Dm644 "$SRC/50-wm8505-init.conf" "$staging/usr/share/alsa/init/postinit/50-wm8505.conf"
install -Dm755 "$SRC/wmt-battery-cal" "$staging/usr/libexec/wmt-battery-cal"
install -Dm644 "$SRC/99-wmt-battery.rules" "$staging/usr/lib/udev/rules.d/99-wmt-battery.rules"
install -Dm755 "$SRC/postinst" "$staging/DEBIAN/postinst"
install -Dm755 "$SRC/postrm" "$staging/DEBIAN/postrm"
printf '%s\n' /etc/alsa/conf.d/50-wm8505.conf > "$staging/DEBIAN/conffiles"
cat > "$staging/DEBIAN/control" <<EOF
Package: wmt-platform-wm8505
Version: $VERSION
Architecture: all
Maintainer: $BUILDER_NAME <$BUILDER_EMAIL>
Section: admin
Priority: optional
Description: WMT OS hardware configuration
 System configuration for the WonderMedia WM8505.
EOF
dpkg-deb --root-owner-group --build "$staging" "$DEBS/wmt-platform-wm8505_${VERSION}_all.deb" >/dev/null
rm -rf "$staging"
