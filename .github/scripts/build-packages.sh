#!/bin/bash
set -e

# Configure git to trust the repository directory
git config --global --add safe.directory "$GITHUB_WORKSPACE"

mkdir -p /tmp/arch-packages

# Create a build user once (can't build as root)
useradd -m builduser
echo "builduser ALL=(ALL) NOPASSWD: /usr/bin/pacman" >> /etc/sudoers

# Check if database exists on www branch
cd "$GITHUB_WORKSPACE"
git fetch origin www:refs/remotes/origin/www 2>/dev/null || true
DB_EXISTS=false
if git show-ref --verify --quiet refs/remotes/origin/www; then
  if git show origin/www:repo/BAR.db.tar.gz >/dev/null 2>&1; then
    echo "✓ Database exists on www branch"
    DB_EXISTS=true
  else
    echo "⚠️ www branch exists but no database found - will build all packages"
  fi
else
  echo "⚠️ No www branch found - will build all packages (first run)"
fi

# Get list of changed PKGBUILD files in the last commit
echo "Detecting changed PKGBUILD files..."
CHANGED_PKGBUILDS=""
if git rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_PKGBUILDS=$(git diff --name-only HEAD~1 HEAD | grep 'PKGBUILD$' || true)
else
  echo "⚠️ No previous commit found (shallow clone or first commit)"
fi

if [ "$DB_EXISTS" = false ]; then
  echo "Building all packages (first run)..."
  CHANGED_PKGBUILDS=$(find . -name PKGBUILD -type f)
elif [ -z "$CHANGED_PKGBUILDS" ]; then
  echo "⚠️ No PKGBUILD files changed in this commit"
  echo "Building all packages as fallback..."
  CHANGED_PKGBUILDS=$(find . -name PKGBUILD -type f)
fi

echo "PKGBUILDs to build:"
echo "$CHANGED_PKGBUILDS"

# Build only changed packages
echo "$CHANGED_PKGBUILDS" | while read pkgbuild; do
  [ -z "$pkgbuild" ] && continue
  
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
