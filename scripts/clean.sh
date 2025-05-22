#!/usr/bin/env bash
# Clean up build artifacts and temporary files

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

# Directories to clean
BUILD_DIR="${REPO_ROOT}/build"
TMP_DIRS=("${REPO_ROOT}/tmp" "${REPO_ROOT}/tmp_test")

# Clean build directory
if [ -d "$BUILD_DIR" ]; then
  echo "Cleaning build directory..."
  rm -rf "${BUILD_DIR:?}"/*
  echo "✅ Build directory cleaned"
else
  echo "Build directory does not exist, nothing to clean"
fi

# Clean any temporary directories
for tmp_dir in "${TMP_DIRS[@]}"; do
  if [ -d "$tmp_dir" ]; then
    echo "Cleaning temporary directory $tmp_dir..."
    rm -rf "${tmp_dir:?}"
    echo "✅ Temporary directory $tmp_dir removed"
  fi
done

echo "🧹 Cleanup complete!"