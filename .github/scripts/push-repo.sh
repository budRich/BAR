#!/bin/bash
set -e

# Create release with timestamp as archive
RELEASE_TAG="build-$(date +%Y.%m.%d-%H%M%S)"
RELEASE_NAME="Arch Packages $(date +%Y-%m-%d)"

echo "Creating release: $RELEASE_TAG"

gh release create "$RELEASE_TAG" \
  --title "$RELEASE_NAME" \
  --notes "Automated package build from commit ${GITHUB_SHA:0:7}" \
  --repo "$GITHUB_REPOSITORY"

# Upload newly built packages to the release as archive
cd /tmp/repo
for pkg in *.pkg.tar.zst; do
  echo "Uploading $pkg to release..."
  gh release upload "$RELEASE_TAG" "$pkg" "$pkg.sig" --repo "$GITHUB_REPOSITORY"
done

# Download existing packages from www branch
echo "Fetching existing packages from www branch..."
mkdir -p /tmp/all-packages
cd /tmp/all-packages

git config --global --add safe.directory "$GITHUB_WORKSPACE"
cd "$GITHUB_WORKSPACE"
git fetch origin www 2>/dev/null || true

if git rev-parse origin/www >/dev/null 2>&1; then
  echo "Downloading existing packages from www branch..."
  git checkout www
  if [ -d repo ]; then
    cp repo/*.pkg.tar.zst* /tmp/all-packages/ 2>/dev/null || true
  fi
  git checkout -
else
  echo "No www branch found, this is the first run"
fi

# Copy newly built packages and extract package names
cd /tmp/repo
for pkg in *.pkg.tar.zst; do
  # Extract package name without version (e.g., i3ass from i3ass-2025.12.27.1-5-any.pkg.tar.zst)
  pkgname=$(echo "$pkg" | sed -E 's/^([^0-9]+)-[0-9].*/\1/')
  
  # Remove old versions of this package from all-packages
  echo "Removing old versions of $pkgname..."
  rm -f /tmp/all-packages/${pkgname}-*.pkg.tar.zst*
  
  # Copy new version
  echo "Adding new version: $pkg"
  cp "$pkg" "$pkg.sig" /tmp/all-packages/
done

# Rebuild the complete database with only latest packages
cd /tmp/all-packages
repo-add --sign --key "$GPG_KEY_ID" BAR.db.tar.gz *.pkg.tar.zst

# Prepare GitHub Pages repo directory
git config --global user.email "github-actions@github.com"
git config --global user.name "github-actions"
cd "$GITHUB_WORKSPACE"
git checkout www || git checkout --orphan www
rm -rf repo
mkdir -p repo

# Copy latest packages and database files to www branch (dereference symlinks)
cp -L /tmp/all-packages/* repo/

cd "$GITHUB_WORKSPACE"
git add repo
git commit -m "Update Arch repo (auto) [skip ci]" || echo "No changes"
git push origin www
