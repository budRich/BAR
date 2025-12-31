#!/bin/bash
set -e

echo "Setting up budRich/BAR repository..."

# Import GPG key
curl -s https://raw.githubusercontent.com/budRich/BAR/master/public-key.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key F76C6FE1A233104A0C53FB3448E97CE0936581E3

if ! grep -q "\[BAR\]" /etc/pacman.conf; then
  echo "" 
  echo "[BAR]"
  echo "Server = https://raw.githubusercontent.com/budRich/BAR/www/repo"
  echo "SigLevel = Required DatabaseOptional"
fi | sudo tee -a /etc/pacman.conf

sudo pacman -Sy
echo "✓ BAR repository is now set up!"
