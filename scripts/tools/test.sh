#!/usr/bin/env bash
set -euo pipefail

# Get directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_ROOT="$(dirname "${PARENT_DIR}")"
TEST_DIR="${REPO_ROOT}/test"

# Make scripts executable
chmod +x "${SCRIPT_DIR}"/*.sh
chmod +x "${TEST_DIR}"/*.sh

# Load common functions if available
COMMON_SCRIPT="${TEST_DIR}/common.sh"
if [ -f "$COMMON_SCRIPT" ]; then
  source "$COMMON_SCRIPT"
fi

# Function to list available tests
list_available_tests() {
  echo "Available tests:"
  for script in "${TEST_DIR}"/test_*.sh; do
    # Skip helper scripts
    if [[ "$(basename "$script")" == *"common.sh"* ]] || \
       [[ "$(basename "$script")" == *"run_all_tests.sh"* ]] || \
       [[ "$(basename "$script")" == *"path_helper.sh"* ]] || \
       [[ "$(basename "$script")" == *"tmp_fix_tests.sh"* ]]; then
      continue
    fi
    
    # Display test name without prefix
    echo "  $(basename "${script}" .sh | sed 's/^test_//')"
  done
}

# Handle different test commands
if [ $# -eq 0 ]; then
  # No arguments, run all tests
  echo "Running all tests..."
  test_script="${TEST_DIR}/run_all_tests.sh"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  # Help command
  echo "Usage: $0 [test_name]"
  echo ""
  echo "Commands:"
  echo "  $0                Run all tests"
  echo "  $0 <test_name>    Run specific test"
  echo "  $0 --list         List available tests"
  echo "  $0 --help         Show this help message"
  echo ""
  list_available_tests
  exit 0
elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
  # List available tests
  list_available_tests
  exit 0
else
  # Run specific test
  test_script="${TEST_DIR}/test_$1.sh"
  if [ ! -f "${test_script}" ]; then
    echo "Error: Test script ${test_script} not found"
    list_available_tests
    exit 1
  fi
  echo "Running test: $1"
fi

# Execute test script
bash "${test_script}"
TEST_RESULT=$?

# Run coverage report
if [ -f "${SCRIPT_DIR}/coverage_report.sh" ]; then
  "${SCRIPT_DIR}/coverage_report.sh" > /dev/null
  
  # Display coverage report
  if [ -f "${REPO_ROOT}/build/coverage/coverage-report.txt" ]; then
    echo ""
    echo "Test Coverage Report:"
    echo "---------------------"
    cat "${REPO_ROOT}/build/coverage/coverage-report.txt"
  fi
fi

# Return test result
exit $TEST_RESULT