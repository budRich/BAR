#!/bin/bash
set -e

mkdir -p /tmp/arch-packages

# Create a build user once (can't build as root)
useradd -m builduser
echo "builduser ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> /etc/sudoers

# Find all PKGBUILD files and build them
find . -name PKGBUILD -type f | while read pkgbuild; do
  pkg_dir=$(dirname "$pkgbuild")
  echo "Building package in $pkg_dir"
  cd "$GITHUB_WORKSPACE/$pkg_dir"
  
  # Clean up any lingering faked processes to prevent IPC errors
  pkill faked || true
  
  chown -R builduser:builduser . 
  
  # Build the package
  sudo -u builduser makepkg -s --nodeps --noconfirm
  
  # Copy built packages
  cp *.pkg.tar.* /tmp/arch-packages/ || true
  
  cd "$GITHUB_WORKSPACE"
done

echo "=== Packages built ==="
ls -lh /tmp/arch-packages
if [ ! -e /tmp/arch-packages/*.pkg.tar.* ]; then
  echo "❌ No packages were built – aborting."
  exit 1
fi
