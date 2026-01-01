#!/bin/bash
set -e

mkdir -p /tmp/repo
cp /tmp/arch-packages/*.pkg.tar.* /tmp/repo/
cd /tmp/repo

# Sign each package
for pkg in *.pkg.tar.*; do
  [[ "$pkg" == *.sig ]] && continue
  gpg --batch --yes --detach-sign --no-armor "$pkg"
done

# Create and sign repo database
# Using --sign ensures repo-add creates the correct .sig symlinks (BAR.db.sig -> BAR.db.tar.gz.sig)
repo-add --sign --key "$GPG_KEY_ID" BAR.db.tar.gz *.pkg.tar.zst

# Verify signatures were created
ls -la *.sig
