#!/bin/bash
set -e

echo "Setting up budRich/BAR repository..."

# Import GPG key
curl -s https://raw.githubusercontent.com/budRich/BAR/master/public-key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 03932D58D15CB5F4E5799586E9C940B5E6BE4258

if ! grep -q "\[BAR\]" /etc/pacman.conf; then
  echo "" 
  echo "[BAR]"
  echo "Server = https://raw.githubusercontent.com/budRich/BAR/www/repo/BAR.server"
  echo "SigLevel = Required DatabaseOptional"
fi | sudo tee -a /etc/pacman.conf

sudo pacman -Sy
echo "✓ BAR repository is now set up!"
