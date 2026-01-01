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

# Download existing database from www branch if it exists
cd "$GITHUB_WORKSPACE"
git fetch origin www 2>/dev/null || true
if git show origin/www:repo/BAR.db.tar.gz > /tmp/existing-BAR.db.tar.gz 2>/dev/null; then
  echo "Found existing database, will update it..."
  cp /tmp/existing-BAR.db.tar.gz /tmp/repo/BAR.db.tar.gz
else
  echo "No existing database found, creating new one..."
fi

# Add new packages to the database (this updates existing or creates new)
cd /tmp/repo
repo-add --sign --key "$GPG_KEY_ID" BAR.db.tar.gz *.pkg.tar.zst

# Create a Server entry file that points to the release
REPO_URL="https://github.com/$GITHUB_REPOSITORY/releases/download/$RELEASE_TAG"
cat > BAR.server <<EOF
# Add this to your pacman.conf [BAR] section as:
# Server = $REPO_URL
# 
# Or use the add-repo.bash script which should handle this automatically.
$REPO_URL
EOF

# Prepare GitHub Pages repo directory
git config --global --add safe.directory "$GITHUB_WORKSPACE"
git config --global user.email "github-actions@github.com"
git config --global user.name "github-actions"
cd "$GITHUB_WORKSPACE"
git checkout www || git checkout --orphan www
rm -rf repo
mkdir -p repo

# Copy database files and server info to www branch (dereference symlinks)
cp -L /tmp/repo/BAR.db* /tmp/repo/BAR.files* /tmp/repo/BAR.server repo/

cd "$GITHUB_WORKSPACE"
git add repo
git commit -m "Update Arch repo databases (auto) [skip ci]" || echo "No changes"
git push origin www
