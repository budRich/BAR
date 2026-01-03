#!/bin/bash
set -e

# this is the same script as what users use
# to setup BAR repo, but with sudo removed
# so we can enable it in our workflow, to be 
# able to install dependencies from it (f.i gtk2)

echo "Setting up budRich/BAR repository..."

# Import GPG key
curl -s https://raw.githubusercontent.com/budRich/BAR/master/public-key.asc | pacman-key --add -
pacman-key --lsign-key 03932D58D15CB5F4E5799586E9C940B5E6BE4258

if ! grep -q "\[BAR\]" /etc/pacman.conf; then
  echo "" 
  echo "[BAR]"
  echo "Server = https://github.com/budRich/BAR/releases/latest/download"
  echo "SigLevel = Required DatabaseOptional"
fi | tee -a /etc/pacman.conf

pacman -Sy
echo "✓ BAR repository is now set up!"
