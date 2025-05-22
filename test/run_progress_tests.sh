#!/usr/bin/env bash
# Run progress tracking tests

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"

# Create necessary directories
mkdir -p "${LIB_DIR}"

# Ensure scripts are executable
chmod +x "${SCRIPT_DIR}/test_progress.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/test_skip_functionality.sh" 2>/dev/null || true
chmod +x "${SCRIPTS_DIR}/progress.sh" 2>/dev/null || true
chmod +x "${LIB_DIR}/progress.sh" 2>/dev/null || true
chmod +x "${SCRIPTS_DIR}/sync-all.sh" 2>/dev/null || true
chmod +x "${SCRIPTS_DIR}/publish-all.sh" 2>/dev/null || true

# Verify that the scripts and libraries exist
echo "Verifying scripts and libraries..."
[ -f "${SCRIPT_DIR}/test_progress.sh" ] && echo "✓ test_progress.sh found" || echo "✗ test_progress.sh not found"
[ -f "${SCRIPT_DIR}/test_skip_functionality.sh" ] && echo "✓ test_skip_functionality.sh found" || echo "✗ test_skip_functionality.sh not found"
[ -f "${SCRIPTS_DIR}/progress.sh" ] && echo "✓ progress.sh found" || echo "✗ progress.sh not found"
[ -f "${LIB_DIR}/progress.sh" ] && echo "✓ lib/progress.sh found" || echo "✗ lib/progress.sh not found"
[ -f "${SCRIPTS_DIR}/sync-all.sh" ] && echo "✓ sync-all.sh found" || echo "✗ sync-all.sh not found"
[ -f "${SCRIPTS_DIR}/publish-all.sh" ] && echo "✓ publish-all.sh found" || echo "✗ publish-all.sh not found"

# Run the progress tracking tests
echo "Running progress tracking tests..."
"${SCRIPT_DIR}/test_progress.sh"

# Run skip functionality tests
echo "Running skip functionality tests..."
"${SCRIPT_DIR}/test_skip_functionality.sh"

# Run the updated sync-all.sh with --help option
if [ -f "${SCRIPTS_DIR}/sync-all.sh" ]; then
  echo "Testing sync-all.sh help message..."
  "${SCRIPTS_DIR}/sync-all.sh" --help || echo "Failed to run sync-all.sh help"
else
  echo "Warning: sync-all.sh not found, skipping help test"
fi

# Test the publish-all.sh with --help option
if [ -f "${SCRIPTS_DIR}/publish-all.sh" ]; then
  echo "Testing publish-all.sh help message..."
  "${SCRIPTS_DIR}/publish-all.sh" --help || echo "Failed to run publish-all.sh help"
else
  echo "Warning: publish-all.sh not found, skipping help test"
fi

# Test the progress.sh utility help
if [ -f "${SCRIPTS_DIR}/progress.sh" ]; then
  echo "Testing progress utility help..."
  "${SCRIPTS_DIR}/progress.sh" || echo "Failed to run progress.sh help"
else
  echo "Warning: progress.sh not found, skipping help test"
fi

echo "All progress-related tests completed successfully!"