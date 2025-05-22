#!/usr/bin/env bash
# Test for progress tracking functionality

set -euo pipefail

# Save current working directory
ORIGINAL_DIR=$(pwd)

# Find the repository root directory
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPTS_DIR="${REPO_ROOT}/scripts"
LIB_DIR="${SCRIPTS_DIR}/lib"

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Setup the test environment
setup_test_env() {
  cd "$TEST_DIR" || exit 1
  
  # Create build directory
  mkdir -p build
  
  # Create scripts directory and lib directory
  mkdir -p scripts/lib
  
  # Copy progress library
  cp "${LIB_DIR}/progress.sh" scripts/lib/ || {
    echo "Error: Failed to copy progress.sh library"
    return 1
  }
  
  # Create a test script to use the progress library
  cat > test_progress_util.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Source the progress library
source "./scripts/lib/progress.sh"

# Initialize progress tracking
init_progress_tracking

# Function to test all operations
test_all_operations() {
  # Test sync operations
  start_sync_tracking "test-module-1"
  start_sync_tracking "test-module-2"
  start_sync_tracking "test-module-3"
  start_sync_tracking "test-module-4"
  
  # Mark different statuses
  sync_in_progress "test-module-1"
  sync_completed "test-module-1"
  
  sync_in_progress "test-module-2"
  sync_failed "test-module-2"
  
  sync_in_progress "test-module-3"
  sync_skipped "test-module-3"
  
  # Test publish operations
  start_publish_tracking "test-sdk-1"
  start_publish_tracking "test-sdk-2"
  start_publish_tracking "test-sdk-3"
  
  # Mark different statuses
  publish_in_progress "test-sdk-1"
  publish_completed "test-sdk-1"
  
  publish_in_progress "test-sdk-2"
  publish_failed "test-sdk-2"
  
  publish_in_progress "test-sdk-3"
  publish_skipped "test-sdk-3"
  
  # Print summary
  print_progress_summary
}

# Function to test get operations
test_get_operations() {
  # Get operation statuses
  echo "Sync module 1 status: $(get_operation_status "$OP_SYNC" "test-module-1")"
  echo "Sync module 2 status: $(get_operation_status "$OP_SYNC" "test-module-2")"
  echo "Sync module 3 status: $(get_operation_status "$OP_SYNC" "test-module-3")"
  
  # Get all operations by status
  echo "Failed operations:"
  get_failed_operations "$OP_SYNC"
  get_failed_operations "$OP_PUBLISH"
  
  echo "Completed operations:"
  get_completed_operations "$OP_SYNC"
  get_completed_operations "$OP_PUBLISH"
  
  echo "Skipped operations:"
  get_skipped_operations "$OP_SYNC"
  get_skipped_operations "$OP_PUBLISH"
}

# Function to test clearing operations
test_clear_operations() {
  # Clear completed operations
  clear_completed_operations
  
  echo "After clearing completed operations:"
  print_progress_summary
  
  # Clear all operations
  clear_progress
  
  echo "After clearing all operations:"
  print_progress_summary
}

# Function to specifically test skipped operations
test_skipped_operations() {
  # Clear previous operations
  clear_progress
  
  # Add operations with different statuses
  start_sync_tracking "skip-test-module-1"
  start_sync_tracking "skip-test-module-2"
  start_publish_tracking "skip-test-sdk-1"
  
  # Mark as skipped
  sync_skipped "skip-test-module-1"
  sync_completed "skip-test-module-2"
  publish_skipped "skip-test-sdk-1"
  
  # Get skipped operations
  echo "Skipped sync operations:"
  get_skipped_operations "$OP_SYNC"
  
  echo "Skipped publish operations:"
  get_skipped_operations "$OP_PUBLISH"
  
  # Verify that skipped operations are included in the percentage calculation
  echo "Progress summary (skipped should count towards completion):"
  print_progress_summary
}

# Run tests
case "${1:-all}" in
  all)
    test_all_operations
    test_get_operations
    test_clear_operations
    test_skipped_operations
    ;;
  add)
    test_all_operations
    ;;
  get)
    test_get_operations
    ;;
  clear)
    test_clear_operations
    ;;
  skipped)
    test_skipped_operations
    ;;
  *)
    echo "Unknown test: $1"
    exit 1
    ;;
esac
EOF
  chmod +x test_progress_util.sh
}

# Test progress tracking initialization
test_init_progress() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # Run the test script
  ./test_progress_util.sh all
  
  # Check if progress file was created
  if [ ! -f "build/progress.json" ]; then
    echo "FAIL: Progress file was not created"
    exit 1
  fi
  
  echo "PASS: Progress tracking initialization test"
}

# Test operation status tracking
test_operation_status() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # Run just the add operations test
  ./test_progress_util.sh add
  
  # Check if completed operations are correct
  completed_sync=$(grep -c "\"status\": *\"completed\"" build/progress.json || echo "0")
  completed_publish=$(grep -c "\"status\": *\"completed\"" build/progress.json || echo "0")
  
  if [ "$completed_sync" -lt 1 ] || [ "$completed_publish" -lt 1 ]; then
    echo "FAIL: Operation status tracking test - missing completed operations"
    exit 1
  fi
  
  # Check if failed operations are correct
  failed_sync=$(grep -c "\"status\": *\"failed\"" build/progress.json || echo "0")
  failed_publish=$(grep -c "\"status\": *\"failed\"" build/progress.json || echo "0")
  
  if [ "$failed_sync" -lt 1 ] || [ "$failed_publish" -lt 1 ]; then
    echo "FAIL: Operation status tracking test - missing failed operations"
    exit 1
  fi
  
  # Check if skipped operations are correct
  skipped_sync=$(grep -c "\"status\": *\"skipped\"" build/progress.json || echo "0")
  skipped_publish=$(grep -c "\"status\": *\"skipped\"" build/progress.json || echo "0")
  
  if [ "$skipped_sync" -lt 1 ] || [ "$skipped_publish" -lt 1 ]; then
    echo "FAIL: Operation status tracking test - missing skipped operations"
    exit 1
  fi
  
  echo "PASS: Operation status tracking test"
}

# Test clearing operations
test_clearing_operations() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # Run the add operations test first
  ./test_progress_util.sh add
  
  # Run the clear operations test
  ./test_progress_util.sh clear
  
  # Check if progress file was reset
  content=$(cat build/progress.json)
  if [ "$content" != '{"operations": []}' ]; then
    echo "FAIL: Clear operations test - progress file was not reset properly"
    exit 1
  fi
  
  echo "PASS: Clear operations test"
}

# Test skipped operations functionality
test_skipped_operations() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # Run the skipped operations test
  ./test_progress_util.sh skipped
  
  # Check if the skipped operations exist in the file
  if [ ! -f "build/progress.json" ]; then
    echo "FAIL: Skipped operations test - progress.json file not found"
    exit 1
  fi
  
  # Print the contents of the file for debugging
  cat build/progress.json
  
  # Just check if the get_skipped_operations functions return the expected values
  # This method is more reliable than trying to grep through the JSON structure
  
  # Check if get_skipped_operations works
  skipped_module=$(./test_progress_util.sh skipped | grep -A1 "Skipped sync operations:" | grep "skip-test-module-1" || echo "")
  if [ -z "$skipped_module" ]; then
    echo "FAIL: get_skipped_operations did not return the skipped module"
    exit 1
  fi
  
  skipped_sdk=$(./test_progress_util.sh skipped | grep -A1 "Skipped publish operations:" | grep "skip-test-sdk-1" || echo "")
  if [ -z "$skipped_sdk" ]; then
    echo "FAIL: get_skipped_operations did not return the skipped SDK"
    exit 1
  fi
  
  echo "PASS: Skipped operations test"
}

# Run all tests
echo "Running progress tracking tests..."
test_init_progress
test_operation_status
test_clearing_operations
test_skipped_operations

echo "All progress tracking tests passed!"

# Restore original directory
cd "$ORIGINAL_DIR"