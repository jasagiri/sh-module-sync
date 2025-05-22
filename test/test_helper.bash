#!/usr/bin/env bash
# Simple test for the test helper functions

echo "Running test helper test..."

# Source the helper
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

# Create a directory for tests in the build folder
TEST_TMP_DIR="${REPO_ROOT}/build/test_helper"
mkdir -p "$TEST_TMP_DIR"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# Setup the test environment
setup_test_environment "$TEST_TMP_DIR"

# Check that mock scripts were created
if [ ! -f "$TEST_TMP_DIR/scripts/add_module.sh" ]; then
  echo "FAIL: add_module.sh mock not created"
  exit 1
fi

if [ ! -f "$TEST_TMP_DIR/scripts/update_module.sh" ]; then
  echo "FAIL: update_module.sh mock not created"
  exit 1
fi

if [ ! -f "$TEST_TMP_DIR/scripts/remove_module.sh" ]; then
  echo "FAIL: remove_module.sh mock not created" 
  exit 1
fi

if [ ! -f "$TEST_TMP_DIR/scripts/sync-all.sh" ]; then
  echo "FAIL: sync-all.sh mock not created"
  exit 1
fi

if [ ! -f "$TEST_TMP_DIR/scripts/publish-all.sh" ]; then
  echo "FAIL: publish-all.sh mock not created"
  exit 1
fi

# Test the get_script_path function
ADD_MODULE_PATH=$(get_script_path "add_module.sh" "$TEST_TMP_DIR")
if [ ! -f "$ADD_MODULE_PATH" ]; then
  echo "FAIL: get_script_path failed to find add_module.sh"
  exit 1
fi

# Run a basic test on the mock scripts
if ! "$ADD_MODULE_PATH" "https://example.com/repo.git" "test-module" | grep -q "Would add module test-module"; then
  echo "FAIL: Mock add_module.sh did not work as expected"
  exit 1
fi

REMOVE_MODULE_PATH=$(get_script_path "remove_module.sh" "$TEST_TMP_DIR")
if ! "$REMOVE_MODULE_PATH" "test-module" | grep -q "Would remove module test-module"; then
  echo "FAIL: Mock remove_module.sh did not work as expected" 
  exit 1
fi

# Test for a non-existent script
NONEXISTENT_PATH=$(get_script_path "nonexistent.sh" "$TEST_TMP_DIR")
if [ ! -f "$NONEXISTENT_PATH" ]; then
  echo "FAIL: get_script_path did not create a placeholder for nonexistent.sh"
  exit 1
fi

echo "✅ Test helper test passed!"
exit 0