#!/usr/bin/env bash
set -euo pipefail

# Test script using mocks to verify module management scripts
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

# Create a directory for tests in the build folder
TEST_TMP_DIR="${REPO_ROOT}/build/test"
mkdir -p "$TEST_TMP_DIR"
trap 'rm -rf "$TEST_TMP_DIR"' EXIT

# Setup test environment with mocks
setup_test_environment "$TEST_TMP_DIR"

# Tests
run_add_module_test() {
  echo "Testing add_module.sh..."
  local script_path
  script_path=$(get_script_path "add_module.sh" "$TEST_TMP_DIR")
  
  # Test with missing arguments - using bash to preserve stderr
  local output
  output=$(bash "$script_path" 2>&1 || true)
  if echo "$output" | grep -q "Usage"; then
    echo "✅ PASS: add_module argument validation"
  else
    echo "❌ FAIL: add_module argument validation"
    echo "   Output was: $output"
    return 1
  fi
  
  # Test with correct arguments
  if "$script_path" "https://example.com/repo.git" "test-module" | grep -q "Would add module test-module"; then
    echo "✅ PASS: add_module successful execution"
  else
    echo "❌ FAIL: add_module successful execution"
    return 1
  fi
  
  return 0
}

run_update_module_test() {
  echo "Testing update_module.sh..."
  local script_path
  script_path=$(get_script_path "update_module.sh" "$TEST_TMP_DIR")
  
  # Test with missing arguments - using bash to preserve stderr
  local output
  output=$(bash "$script_path" 2>&1 || true)
  if echo "$output" | grep -q "Usage"; then
    echo "✅ PASS: update_module argument validation"
  else
    echo "❌ FAIL: update_module argument validation"
    echo "   Output was: $output"
    return 1
  fi
  
  # Test with correct arguments
  if "$script_path" "test-module" | grep -q "Would update module test-module"; then
    echo "✅ PASS: update_module successful execution"
  else
    echo "❌ FAIL: update_module successful execution"
    return 1
  fi
  
  return 0
}

run_remove_module_test() {
  echo "Testing remove_module.sh..."
  local script_path
  script_path=$(get_script_path "remove_module.sh" "$TEST_TMP_DIR")
  
  # Test with missing arguments - using bash to preserve stderr
  local output
  output=$(bash "$script_path" 2>&1 || true)
  if echo "$output" | grep -q "Usage"; then
    echo "✅ PASS: remove_module argument validation"
  else
    echo "❌ FAIL: remove_module argument validation"
    echo "   Output was: $output"
    return 1
  fi
  
  # Test with correct arguments
  if "$script_path" "test-module" | grep -q "Would remove module test-module"; then
    echo "✅ PASS: remove_module successful execution"
  else
    echo "❌ FAIL: remove_module successful execution"
    return 1
  fi
  
  return 0
}

run_sync_all_test() {
  echo "Testing sync-all.sh..."
  local script_path
  script_path=$(get_script_path "sync-all.sh" "$TEST_TMP_DIR")
  
  # Test successful execution
  local output
  output=$("$script_path")
  
  if echo "$output" | grep -q "Syncing module1"; then
    echo "✅ PASS: sync-all contains expected module1"
  else
    echo "❌ FAIL: sync-all missing expected module1"
    return 1
  fi
  
  if echo "$output" | grep -q "All modules synced successfully"; then
    echo "✅ PASS: sync-all successful completion"
  else
    echo "❌ FAIL: sync-all missing success message"
    return 1
  fi
  
  # Test skip functionality
  output=$("$script_path" --skip module1)
  
  if echo "$output" | grep -q "Skipping module1"; then
    echo "✅ PASS: sync-all correctly skips specified module"
  else
    echo "❌ FAIL: sync-all not skipping specified module"
    return 1
  fi
  
  # Test list-skipped option
  output=$("$script_path" --list-skipped)
  
  if echo "$output" | grep -q "kipped"; then
    echo "✅ PASS: sync-all --list-skipped works correctly"
  else
    echo "❌ FAIL: sync-all --list-skipped not working"
    return 1
  fi
  
  return 0
}

run_publish_all_test() {
  echo "Testing publish-all.sh..."
  local script_path
  script_path=$(get_script_path "publish-all.sh" "$TEST_TMP_DIR")
  
  # Test successful execution
  local output
  output=$("$script_path")
  
  if echo "$output" | grep -q "Publishing sync-sdk"; then
    echo "✅ PASS: publish-all contains expected SDK"
  else
    echo "❌ FAIL: publish-all missing expected SDK"
    return 1
  fi
  
  if echo "$output" | grep -q "All SDKs published successfully"; then
    echo "✅ PASS: publish-all successful completion"
  else
    echo "❌ FAIL: publish-all missing success message"
    return 1
  fi
  
  # Test skip functionality
  output=$("$script_path" --skip sync-sdk)
  
  if echo "$output" | grep -q "Skipping sync-sdk"; then
    echo "✅ PASS: publish-all correctly skips specified SDK"
  else
    echo "❌ FAIL: publish-all not skipping specified SDK"
    return 1
  fi
  
  # Test list-skipped option
  output=$("$script_path" --list-skipped)
  
  if echo "$output" | grep -q "kipped"; then
    echo "✅ PASS: publish-all --list-skipped works correctly"
  else
    echo "❌ FAIL: publish-all --list-skipped not working"
    return 1
  fi
  
  return 0
}

run_progress_skip_test() {
  echo "Testing progress.sh skip functionality..."
  local script_path
  script_path=$(get_script_path "progress.sh" "$TEST_TMP_DIR")
  
  # Test list-sync-skipped option
  local output
  output=$("$script_path" list-sync-skipped)
  
  if echo "$output" | grep -q "kipped"; then
    echo "✅ PASS: progress.sh list-sync-skipped functions correctly"
  else
    echo "❌ FAIL: progress.sh list-sync-skipped not working"
    return 1
  fi
  
  # Test list-publish-skipped option
  output=$("$script_path" list-publish-skipped)
  
  if echo "$output" | grep -q "kipped"; then
    echo "✅ PASS: progress.sh list-publish-skipped functions correctly"
  else
    echo "❌ FAIL: progress.sh list-publish-skipped not working"
    return 1
  fi
  
  # Test summary includes skipped operations
  output=$("$script_path" summary)
  
  if echo "$output" | grep -q "kipped"; then
    echo "✅ PASS: progress.sh summary includes skipped operations"
  else
    echo "❌ FAIL: progress.sh summary doesn't include skipped operations"
    return 1
  fi
  
  return 0
}

# Run all tests
echo "Running mock-based tests..."

# Track results
TESTS_PASSED=0
TESTS_FAILED=0

# Run add_module test
if run_add_module_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run update_module test
if run_update_module_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run remove_module test
if run_remove_module_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run sync-all test
if run_sync_all_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run publish-all test
if run_publish_all_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Run progress skip test
if run_progress_skip_test; then
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Print summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Total tests: $((TESTS_PASSED + TESTS_FAILED))"

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo "✅ All mock tests passed!"
  exit 0
else
  echo "❌ Some mock tests failed"
  exit 1
fi