#!/bin/bash
set -e

# Get list of newly built package names
BUILT_PACKAGES=$(cd /tmp/repo && ls *.pkg.tar.zst | sed -E 's/^([^0-9]+)-[0-9].*/\1/' | sort -u)
echo "Newly built packages: $BUILT_PACKAGES"

# Download all packages from the latest release (except ones we just built)
echo "Fetching packages from latest release..."
mkdir -p /tmp/all-packages
cd /tmp/all-packages

LATEST_RELEASE=$(gh release list --repo "$GITHUB_REPOSITORY" --limit 1 | cut -f3 || true)

if [ -n "$LATEST_RELEASE" ]; then
  echo "Downloading packages from release: $LATEST_RELEASE"
  
  # Download all package files
  gh release download "$LATEST_RELEASE" --repo "$GITHUB_REPOSITORY" --pattern "*.pkg.tar.zst" --pattern "*.pkg.tar.zst.sig" 2>/dev/null || true
  
  # Remove packages we just built (we'll copy fresh versions)
  for pkgname in $BUILT_PACKAGES; do
    echo "Skipping old versions of $pkgname (we have fresh builds)..."
    rm -f ${pkgname}-*.pkg.tar.zst*
  done
else
  echo "No previous release found, this is the first release"
fi

# Copy newly built packages
cd /tmp/repo
for pkg in *.pkg.tar.zst; do
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
OLD_RELEASES=$(gh release list --repo "$GITHUB_REPOSITORY" --limit 1000 | cut -f3 | grep -v "^$RELEASE_TAG$" || true)

if [ -n "$OLD_RELEASES" ]; then
  echo "$OLD_RELEASES" | while read old_release; do
    [ -z "$old_release" ] && continue
    echo "Deleting old release: $old_release"
    gh release delete "$old_release" --repo "$GITHUB_REPOSITORY" --yes --cleanup-tag
  done
  echo "✓ Old releases cleaned up"
else
  echo "No old releases to delete"
fi

echo "✓ Packages available at: https://github.com/$GITHUB_REPOSITORY/releases/latest/download/"
