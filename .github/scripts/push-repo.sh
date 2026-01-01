#!/bin/bash
set -e

git config --global --add safe.directory "$GITHUB_WORKSPACE"
git config --global user.email "github-actions@github.com"
git config --global user.name "github-actions"
git fetch origin www || git checkout --orphan www
git checkout www || git checkout --orphan www
rm -rf repo
mkdir -p repo
cp -rL /tmp/repo/* repo/
git add repo
git commit -m "Update Arch repo (auto) [skip ci]" || echo "No changes"
git push origin www
