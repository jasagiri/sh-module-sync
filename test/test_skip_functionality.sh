#!/usr/bin/env bash
# Test for skipping functionality in sync-all.sh and publish-all.sh

set -euo pipefail

# Save current working directory
ORIGINAL_DIR=$(pwd)

# Find the repository root directory
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPTS_DIR="${REPO_ROOT}/scripts"

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Setup the test environment for sync-all.sh
setup_sync_env() {
  cd "$TEST_DIR" || exit 1
  
  # Create necessary directories
  mkdir -p scripts/lib build
  
  # Copy scripts
  cp "${SCRIPTS_DIR}/sync-all.sh" scripts/ || {
    echo "Error: Failed to copy sync-all.sh"
    return 1
  }
  
  # Create mock lib/progress.sh
  cat > scripts/lib/progress.sh << 'EOF'
#!/usr/bin/env bash
# Mock progress tracking library

# Create build directory if it doesn't exist
BUILD_DIR="./build"
mkdir -p "$BUILD_DIR"

# Progress tracking file
PROGRESS_FILE="${BUILD_DIR}/progress.json"

# Operation types
OP_SYNC="sync"
OP_PUBLISH="publish"

# Operation statuses
STATUS_PENDING="pending"
STATUS_IN_PROGRESS="in_progress"
STATUS_COMPLETED="completed"
STATUS_FAILED="failed"
STATUS_SKIPPED="skipped"

# Initialize progress tracking
init_progress_tracking() {
  echo '{"operations": []}' > "$PROGRESS_FILE"
}

# Start tracking a sync operation
start_sync_tracking() {
  echo "Mock: start_sync_tracking $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Start tracking a publish operation
start_publish_tracking() {
  echo "Mock: start_publish_tracking $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark sync operation as in progress
sync_in_progress() {
  echo "Mock: sync_in_progress $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark sync operation as completed
sync_completed() {
  echo "Mock: sync_completed $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark sync operation as failed
sync_failed() {
  echo "Mock: sync_failed $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark sync operation as skipped
sync_skipped() {
  echo "Mock: sync_skipped $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark publish operation as in progress
publish_in_progress() {
  echo "Mock: publish_in_progress $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark publish operation as completed
publish_completed() {
  echo "Mock: publish_completed $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark publish operation as failed
publish_failed() {
  echo "Mock: publish_failed $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Mark publish operation as skipped
publish_skipped() {
  echo "Mock: publish_skipped $1" >> "${BUILD_DIR}/progress_log.txt"
}

# Get failed operations
get_failed_operations() {
  if [ "$1" == "sync" ]; then
    echo "failed-module-1"
    echo "failed-module-2"
  else
    echo "failed-sdk-1"
    echo "failed-sdk-2"
  fi
}

# Get skipped operations
get_skipped_operations() {
  if [ "$1" == "sync" ]; then
    echo "skipped-module-1"
    echo "skipped-module-2"
  else
    echo "skipped-sdk-1"
    echo "skipped-sdk-2"
  fi
}

# Get pending operations
get_pending_operations() {
  if [ "$1" == "sync" ]; then
    echo "pending-module-1"
    echo "pending-module-2"
  else
    echo "pending-sdk-1"
    echo "pending-sdk-2"
  fi
}

# Print progress summary
print_progress_summary() {
  echo "Mock: print_progress_summary" >> "${BUILD_DIR}/progress_log.txt"
  echo "Progress Summary (Mock):"
  echo "Total operations: 10 (40% complete)"
  echo "Pending: 4"
  echo "In Progress: 0"
  echo "Completed: 2"
  echo "Skipped: 2"
  echo "Failed: 2"
}

export -f init_progress_tracking
export -f start_sync_tracking
export -f start_publish_tracking
export -f sync_in_progress
export -f sync_completed
export -f sync_failed
export -f sync_skipped
export -f publish_in_progress
export -f publish_completed
export -f publish_failed
export -f publish_skipped
export -f get_failed_operations
export -f get_skipped_operations
export -f get_pending_operations
export -f print_progress_summary
EOF

  # Create mock lib/config.sh
  cat > scripts/lib/config.sh << 'EOF'
#!/usr/bin/env bash
# Mock configuration library

# Get module names
get_module_names() {
  echo "module1"
  echo "module2"
  echo "module3"
  echo "module4"
}

# Get SDK names
get_sdk_names() {
  echo "sdk1"
  echo "sdk2"
  echo "sdk3"
  echo "sdk4"
}

# Get SDK path
get_sdk_path() {
  echo "./$1"
}

export -f get_module_names
export -f get_sdk_names
export -f get_sdk_path
EOF

  # Create mock update_module.sh
  cat > scripts/update_module.sh << 'EOF'
#!/usr/bin/env bash
# Mock update module script

MODULE=$1
echo "Mock: Updating module ${MODULE}"

# Create a file to track which modules were updated
echo "${MODULE}" >> build/updated_modules.txt

# Return success
exit 0
EOF
  chmod +x scripts/update_module.sh
}

# Setup the test environment for publish-all.sh
setup_publish_env() {
  cd "$TEST_DIR" || exit 1
  
  # Create necessary directories
  mkdir -p scripts/lib build
  
  # Copy scripts
  cp "${SCRIPTS_DIR}/publish-all.sh" scripts/ || {
    echo "Error: Failed to copy publish-all.sh"
    return 1
  }
  
  # Create a mock nimble command
  cat > nimble << 'EOF'
#!/usr/bin/env bash
echo "Mock: Publishing with nimble"
exit 0
EOF
  chmod +x nimble
  export PATH="${TEST_DIR}:${PATH}"
}

# Test sync-all.sh skipping functionality
test_sync_skip() {
  setup_sync_env
  cd "$TEST_DIR" || exit 1
  
  # Run sync-all with skip option
  ./scripts/sync-all.sh --skip module2 --skip module4
  
  # Check if the skipped modules were skipped
  if grep -q "module2" build/updated_modules.txt; then
    echo "FAIL: Module 'module2' was updated but should have been skipped"
    exit 1
  fi
  
  if grep -q "module4" build/updated_modules.txt; then
    echo "FAIL: Module 'module4' was updated but should have been skipped"
    exit 1
  fi
  
  # Check if the non-skipped modules were updated
  if ! grep -q "module1" build/updated_modules.txt; then
    echo "FAIL: Module 'module1' was not updated"
    exit 1
  fi
  
  if ! grep -q "module3" build/updated_modules.txt; then
    echo "FAIL: Module 'module3' was not updated"
    exit 1
  fi
  
  # Check if progress tracking was updated correctly
  if ! grep -q "sync_skipped module2" build/progress_log.txt; then
    echo "FAIL: sync_skipped was not called for module2"
    exit 1
  fi
  
  if ! grep -q "sync_skipped module4" build/progress_log.txt; then
    echo "FAIL: sync_skipped was not called for module4"
    exit 1
  fi
  
  echo "PASS: sync-all.sh skip functionality test"
}

# Test sync-all.sh list-skipped functionality
test_sync_list_skipped() {
  setup_sync_env
  cd "$TEST_DIR" || exit 1
  
  # Run sync-all with list-skipped option
  output=$(./scripts/sync-all.sh --list-skipped)
  
  # Check if the output contains the skipped modules
  if ! echo "$output" | grep -q "skipped-module-1"; then
    echo "FAIL: Output missing skipped-module-1"
    exit 1
  fi
  
  if ! echo "$output" | grep -q "skipped-module-2"; then
    echo "FAIL: Output missing skipped-module-2"
    exit 1
  fi
  
  echo "PASS: sync-all.sh list-skipped functionality test"
}

# Test publish-all.sh skipping functionality
test_publish_skip() {
  setup_sync_env
  setup_publish_env
  cd "$TEST_DIR" || exit 1
  
  # Clear previous logs
  > build/progress_log.txt
  
  # Create SDK directories to prevent pushd/popd errors
  mkdir -p sdk1 sdk2 sdk3 sdk4
  
  # Run publish-all with skip option
  ./scripts/publish-all.sh --skip sdk2 --skip sdk4
  
  # Check if progress tracking was updated correctly
  if ! grep -q "publish_skipped sdk2" build/progress_log.txt; then
    echo "FAIL: publish_skipped was not called for sdk2"
    exit 1
  fi
  
  if ! grep -q "publish_skipped sdk4" build/progress_log.txt; then
    echo "FAIL: publish_skipped was not called for sdk4"
    exit 1
  fi
  
  echo "PASS: publish-all.sh skip functionality test"
}

# Test publish-all.sh list-skipped functionality
test_publish_list_skipped() {
  setup_sync_env
  setup_publish_env
  cd "$TEST_DIR" || exit 1
  
  # Run publish-all with list-skipped option
  output=$(./scripts/publish-all.sh --list-skipped)
  
  # Check if the output contains the skipped SDKs
  if ! echo "$output" | grep -q "skipped-sdk-1"; then
    echo "FAIL: Output missing skipped-sdk-1"
    exit 1
  fi
  
  if ! echo "$output" | grep -q "skipped-sdk-2"; then
    echo "FAIL: Output missing skipped-sdk-2"
    exit 1
  fi
  
  echo "PASS: publish-all.sh list-skipped functionality test"
}

# Test that non-zero exit code is only for failed operations, not skipped ones
test_exit_code() {
  setup_sync_env
  setup_publish_env
  cd "$TEST_DIR" || exit 1
  
  # Create SDK directories to prevent pushd/popd errors
  mkdir -p sdk1 sdk2 sdk3 sdk4
  
  # Create a failing update_module.sh for module3
  cat > scripts/update_module.sh << 'EOF'
#!/usr/bin/env bash
# Mock update module script with failures

MODULE=$1
echo "${MODULE}" >> build/updated_modules.txt

if [ "$MODULE" = "module3" ]; then
  echo "Mock: Failed to update module ${MODULE}" >&2
  exit 1
else
  echo "Mock: Updating module ${MODULE}"
  exit 0
fi
EOF
  chmod +x scripts/update_module.sh
  
  # Run sync-all with skip option
  if ./scripts/sync-all.sh --skip module2 --skip module4; then
    echo "FAIL: Script should have failed due to module3 failing"
    exit 1
  fi
  
  # Now skip the failing module
  > build/updated_modules.txt
  if ! ./scripts/sync-all.sh --skip module2 --skip module3 --skip module4; then
    echo "FAIL: Script should have succeeded with all potential failures skipped"
    exit 1
  fi
  
  echo "PASS: Exit code functionality test"
}

# Run all tests
echo "Running skip functionality tests..."
test_sync_skip
test_sync_list_skipped
test_publish_skip
test_publish_list_skipped
test_exit_code

echo "All skip functionality tests passed!"

# Restore original directory
cd "$ORIGINAL_DIR"