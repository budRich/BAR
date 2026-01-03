#!/bin/bash
set -e

echo "Setting up budRich/BAR repository..."

# Initialize pacman keyring if needed
if [ ! -d /etc/pacman.d/gnupg ]; then
  echo "Initializing pacman keyring..."
  sudo pacman-key --init
  sudo pacman-key --populate archlinux
fi

# Import GPG key
curl -s https://raw.githubusercontent.com/budRich/BAR/master/public-key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 03932D58D15CB5F4E5799586E9C940B5E6BE4258

if ! grep -q "\[BAR\]" /etc/pacman.conf; then
  echo "" 
  echo "[BAR]"
  echo "Server = https://github.com/budRich/BAR/releases/latest/download"
  echo "SigLevel = Required DatabaseOptional"
fi | sudo tee -a /etc/pacman.conf

sudo pacman -Sy
echo "✓ BAR repository is now set up!"
