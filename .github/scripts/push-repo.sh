#!/bin/bash
set -e

# Create release with timestamp
RELEASE_TAG="build-$(date +%Y.%m.%d-%H%M%S)"
RELEASE_NAME="Arch Packages $(date +%Y-%m-%d)"

echo "Creating release: $RELEASE_TAG"

gh release create "$RELEASE_TAG" \
  --title "$RELEASE_NAME" \
  --notes "Automated package build from commit ${GITHUB_SHA:0:7}" \
  --repo "$GITHUB_REPOSITORY"

# Upload all package files to the release
cd /tmp/repo
for pkg in *.pkg.tar.zst; do
  echo "Uploading $pkg to release..."
  gh release upload "$RELEASE_TAG" "$pkg" "$pkg.sig" --repo "$GITHUB_REPOSITORY"
done

# Modify database to use full URLs for packages
REPO_URL="https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG"
echo "Modifying database to use release URLs..."

# Extract the database
mkdir -p /tmp/db-extract
cd /tmp/db-extract
tar -xzf /tmp/repo/BAR.db.tar.gz

# Update FILENAME entries to full URLs in each package desc file
for pkg_dir in */; do
  if [ -f "${pkg_dir}desc" ]; then
    # Replace the filename with full URL
    sed -i "s|^\\(.*\\.pkg\\.tar\\.zst\\)$|${REPO_URL}/\\1|" "${pkg_dir}desc"
  fi
done

# Repack the modified database
tar -czf /tmp/repo/BAR.db.tar.gz *
cd /tmp/repo

# Re-sign the modified database
rm -f BAR.db.tar.gz.sig BAR.db.sig
gpg --batch --yes --detach-sign --no-armor BAR.db.tar.gz
ln -sf BAR.db.tar.gz BAR.db
ln -sf BAR.db.tar.gz.sig BAR.db.sig

# Prepare GitHub Pages repo directory
git config --global --add safe.directory "$GITHUB_WORKSPACE"
git config --global user.email "github-actions@github.com"
git config --global user.name "github-actions"
cd "$GITHUB_WORKSPACE"
git fetch origin www || git checkout --orphan www
git checkout www || git checkout --orphan www
rm -rf repo
mkdir -p repo

# Copy only database files to www branch (dereference symlinks)
cp -L /tmp/repo/BAR.db* /tmp/repo/BAR.files* repo/

cd "$GITHUB_WORKSPACE"
git add repo
git commit -m "Update Arch repo databases (auto) [skip ci]" || echo "No changes"
git push origin www
