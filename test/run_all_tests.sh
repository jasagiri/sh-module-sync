#!/usr/bin/env bash
set -euo pipefail

# Load test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
  source "${SCRIPT_DIR}/common.sh"
fi

# Also load the test helper
if [ -f "${SCRIPT_DIR}/test_helper.sh" ]; then
  source "${SCRIPT_DIR}/test_helper.sh"
fi

# Ensure scripts are executable
ensure_executables

# Initialize test environment
mkdir -p "${REPO_ROOT}/build"

# Track test results
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_SCRIPT_NAMES=()

# Print header for test run
print_header "Running All Module Sync Tests"

# Get all test scripts
TEST_SCRIPTS=($(get_test_scripts))

# Exclude helper scripts
EXCLUDE_PATTERNS=("common.sh" "run_all_tests.sh" "path_helper.sh")
FILTERED_SCRIPTS=()

for script in "${TEST_SCRIPTS[@]}"; do
  skip=false
  for pattern in "${EXCLUDE_PATTERNS[@]}"; do
    if [[ "$(basename "$script")" == *"$pattern"* ]]; then
      skip=true
      break
    fi
  done
  
  if [ "$skip" = false ]; then
    FILTERED_SCRIPTS+=("$script")
  fi
done

# Run each test script
for test_script in "${FILTERED_SCRIPTS[@]}"; do
  TEST_NAME=$(basename "$test_script" .sh | sed 's/^test_//')
  
  echo "----------------------------------------"
  echo "Running test: ${TEST_NAME}"
  echo "----------------------------------------"
  
  if [ -f "$test_script" ] && [ -s "$test_script" ]; then
    # Execute the test script
    if bash "$test_script"; then
      print_result "$TEST_NAME" 0
      PASSED_TESTS=$((PASSED_TESTS+1))
    else
      print_result "$TEST_NAME" 1
      FAILED_TESTS=$((FAILED_TESTS+1))
      FAILED_SCRIPT_NAMES+=("$TEST_NAME")
    fi
  else
    echo "⚠️ Test script ${test_script} doesn't exist or is empty"
    FAILED_TESTS=$((FAILED_TESTS+1))
    FAILED_SCRIPT_NAMES+=("$TEST_NAME (missing)")
  fi
done

# Print summary
print_summary "$PASSED_TESTS" "$FAILED_TESTS"

# Generate coverage report
if [ -f "${SCRIPTS_DIR}/coverage_report.sh" ]; then
  "${SCRIPTS_DIR}/coverage_report.sh"
else
  "${SCRIPTS_DIR}/generate_coverage.sh"
fi

# Return appropriate exit code
if [ "$FAILED_TESTS" -gt 0 ]; then
  echo "Failed scripts:"
  for script in "${FAILED_SCRIPT_NAMES[@]}"; do
    echo "  - ${script}"
  done
  exit 1
else
  exit 0
fi