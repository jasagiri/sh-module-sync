#!/usr/bin/env bash
# Common utility functions for tests

# Get directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
SCRIPTS_DIR="${REPO_ROOT}/scripts"

# Make scripts executable
ensure_executables() {
  chmod +x "${SCRIPTS_DIR}"/*.sh 2>/dev/null || true
  chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
}

# Create test directory and clean on exit
setup_test_dir() {
  local test_dir
  test_dir=$(mktemp -d)
  trap 'rm -rf "$test_dir"' EXIT
  echo "$test_dir"
}

# Get a list of all test scripts
get_test_scripts() {
  find "${SCRIPT_DIR}" -name "test_*.sh" -type f | sort
}

# Print header
print_header() {
  local title="$1"
  echo ""
  echo "========================================"
  echo "  ${title}"
  echo "========================================"
  echo ""
}

# Print test result
print_result() {
  local test_name="$1"
  local result="$2"
  
  if [ "$result" -eq 0 ]; then
    echo "✅ PASS: ${test_name}"
  else
    echo "❌ FAIL: ${test_name}"
  fi
}

# Initialize coverage directory
init_coverage() {
  mkdir -p "${REPO_ROOT}/coverage"
}

# Summary report
print_summary() {
  local passed="$1"
  local failed="$2"
  local total=$((passed + failed))
  
  echo ""
  print_header "Test Summary"
  echo "Tests passed: ${passed}"
  echo "Tests failed: ${failed}"
  echo "Total: ${total}"
  
  if [ "$failed" -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
  else
    echo ""
    echo "❌ Some tests failed!"
  fi
}