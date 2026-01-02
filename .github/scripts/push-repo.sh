#!/bin/bash
set -e

# Download all packages from the latest release
echo "Fetching packages from latest release..."
mkdir -p /tmp/all-packages
cd /tmp/all-packages

LATEST_RELEASE=$(gh release list --repo "$GITHUB_REPOSITORY" --limit 1 | cut -f1 || true)

if [ -n "$LATEST_RELEASE" ]; then
  echo "Downloading packages from release: $LATEST_RELEASE"
  gh release download "$LATEST_RELEASE" --repo "$GITHUB_REPOSITORY" --pattern "*.pkg.tar.zst" --pattern "*.pkg.tar.zst.sig" 2>/dev/null || true
else
  echo "No previous release found, this is the first release"
fi

# Copy newly built packages and remove old versions
cd /tmp/repo
for pkg in *.pkg.tar.zst; do
  # Extract package name without version (e.g., i3ass from i3ass-2025.12.27.1-5-any.pkg.tar.zst)
  pkgname=$(echo "$pkg" | sed -E 's/^([^0-9]+)-[0-9].*/\1/')
  
  # Remove old versions of this package
  echo "Removing old versions of $pkgname..."
  rm -f /tmp/all-packages/${pkgname}-*.pkg.tar.zst*
  
  # Copy new version
  echo "Adding new version: $pkg"
  cp "$pkg" "$pkg.sig" /tmp/all-packages/
done

# Rebuild the complete database with all packages
cd /tmp/all-packages
repo-add --sign --key "$GPG_KEY_ID" BAR.db.tar.gz *.pkg.tar.zst

# Create release with timestamp
RELEASE_TAG="build-$(date +%Y.%m.%d-%H%M%S)"
RELEASE_NAME="Arch Packages $(date +%Y-%m-%d)"

echo "Creating release: $RELEASE_TAG"

gh release create "$RELEASE_TAG" \
  --title "$RELEASE_NAME" \
  --notes "Automated package build from commit ${GITHUB_SHA:0:7}" \
  --repo "$GITHUB_REPOSITORY"

# Upload ALL packages and database files to the release
echo "Uploading all packages and database to release..."
cd /tmp/all-packages
for file in *; do
  echo "Uploading $file..."
  gh release upload "$RELEASE_TAG" "$file" --repo "$GITHUB_REPOSITORY"
done

echo "✓ Release $RELEASE_TAG created successfully!"

# Delete all old releases (keep only the latest)
echo "Cleaning up old releases..."
OLD_RELEASES=$(gh release list --repo "$GITHUB_REPOSITORY" --limit 1000 | grep -v "^$RELEASE_TAG" | cut -f1 || true)

if [ -n "$OLD_RELEASES" ]; then
  echo "$OLD_RELEASES" | while read old_release; do
    [ -z "$old_release" ] && continue
    echo "Deleting old release: $old_release"
    gh release delete "$old_release" --repo "$GITHUB_REPOSITORY" --yes
  done
  echo "✓ Old releases cleaned up"
else
  echo "No old releases to delete"
fi

echo "✓ Packages available at: https://github.com/$GITHUB_REPOSITORY/releases/latest/download/"
