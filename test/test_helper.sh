#!/usr/bin/env bash
# Helper functions for tests

# Find the script directory
export TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export REPO_ROOT=$(dirname "$TEST_DIR")
export SCRIPTS_DIR="$REPO_ROOT/scripts"

# Create test directory files for mocks
setup_test_environment() {
  local test_dir="$1"
  
  # Create mock script files in the test directory
  mkdir -p "$test_dir/scripts"
  
  # Create a build directory symlink for compatibility
  mkdir -p "${REPO_ROOT}/build"
  
  # Mock add_module.sh
  cat > "$test_dir/scripts/add_module.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 引数チェック
if [ $# -ne 2 ]; then
  echo "Usage: $0 <git_repo_url> <module_name>"
  exit 1
fi

REPO_URL=$1
MODULE=$2
echo "Would add module $MODULE from $REPO_URL"
exit 0
EOF
  chmod +x "$test_dir/scripts/add_module.sh"
  
  # Mock update_module.sh
  cat > "$test_dir/scripts/update_module.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 引数チェック
if [ $# -ne 1 ]; then
  echo "Usage: $0 <module_name>"
  exit 1
fi

MODULE=$1
echo "Would update module $MODULE"
exit 0
EOF
  
  # Mock remove_module.sh
  cat > "$test_dir/scripts/remove_module.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 引数チェック
if [ $# -ne 1 ]; then
  echo "Usage: $0 <module_name>"
  exit 1
fi

MODULE=$1
echo "Would remove module $MODULE"
exit 0
EOF

  # Mock sync-all.sh
  cat > "$test_dir/scripts/sync-all.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Command line options
LIST_SKIPPED=false
SKIP_MODULES=""

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-skipped|-s)
      LIST_SKIPPED=true
      shift
      ;;
    --skip)
      if [ -z "$2" ] || [[ "$2" == --* ]]; then
        echo "Error: --skip requires a module name argument" >&2
        exit 1
      fi
      if [ -z "$SKIP_MODULES" ]; then
        SKIP_MODULES="$2"
      else
        SKIP_MODULES="$SKIP_MODULES,$2"
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# List skipped modules if requested
if [ "$LIST_SKIPPED" = true ]; then
  echo "Skipped modules:"
  echo "- mock-skipped-module-1"
  echo "- mock-skipped-module-2"
  exit 0
fi

# Convert skip modules to array
if [ -n "$SKIP_MODULES" ]; then
  IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_MODULES"
else
  SKIP_ARRAY=()
fi

# Helper function to check if a module should be skipped
should_skip() {
  local module_name="$1"
  
  for skip_module in "${SKIP_ARRAY[@]}"; do
    if [ "$skip_module" = "$module_name" ]; then
      return 0  # Should skip
    fi
  done
  
  return 1  # Should not skip
}

# モジュール一覧
MODULES=(
  "module1" "module2" "module3" "module4"
)

# 各モジュールを同期
for module in "${MODULES[@]}"; do
  # Check if module should be skipped
  if should_skip "$module"; then
    echo "Skipping ${module}..."
    continue
  fi

  echo "Syncing ${module}..."
  echo "Mock: Updating module ${module}"
done

echo "✅ All modules synced successfully"
EOF

  # Mock publish-all.sh
  cat > "$test_dir/scripts/publish-all.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Command line options
LIST_SKIPPED=false
SKIP_SDKS=""

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list-skipped|-s)
      LIST_SKIPPED=true
      shift
      ;;
    --skip)
      if [ -z "$2" ] || [[ "$2" == --* ]]; then
        echo "Error: --skip requires an SDK name argument" >&2
        exit 1
      fi
      if [ -z "$SKIP_SDKS" ]; then
        SKIP_SDKS="$2"
      else
        SKIP_SDKS="$SKIP_SDKS,$2"
      fi
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

# List skipped SDKs if requested
if [ "$LIST_SKIPPED" = true ]; then
  echo "Skipped SDKs:"
  echo "- mock-skipped-sdk-1"
  echo "- mock-skipped-sdk-2"
  exit 0
fi

# Convert skip SDKs to array
if [ -n "$SKIP_SDKS" ]; then
  IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_SDKS"
else
  SKIP_ARRAY=()
fi

# Helper function to check if an SDK should be skipped
should_skip() {
  local sdk_name="$1"
  
  for skip_sdk in "${SKIP_ARRAY[@]}"; do
    if [ "$skip_sdk" = "$sdk_name" ]; then
      return 0  # Should skip
    fi
  done
  
  return 1  # Should not skip
}

# 公開対象SDK一覧
SDKS=(
  "sync-sdk" "ai-sdk" "storage-sdk" "security-sdk"
  "net-sdk" "ui-sdk" "obs-sdk" "devops-sdk"
  "api-gateway-sdk" "config-sdk" "cli-sdk" "docs-sdk"
  "test-sdk" "compliance-sdk"
)

# 各SDKを公開
for sdk in "${SDKS[@]}"; do
  # Check if SDK should be skipped
  if should_skip "$sdk"; then
    echo "Skipping ${sdk}..."
    continue
  fi
  
  echo "Publishing ${sdk}..."
  echo "Publishing package..."
  echo "✅ ${sdk} published"
done

echo "🎉 All SDKs published successfully"
EOF

  # Mock progress.sh
  cat > "$test_dir/scripts/progress.sh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <command> [arguments]"
  echo ""
  echo "Progress Commands:"
  echo "  summary                      Show progress summary"
  echo "  list-sync-failed             List failed sync operations"
  echo "  list-publish-failed          List failed publish operations"
  echo "  list-sync-pending            List pending sync operations"
  echo "  list-publish-pending         List pending publish operations"
  echo "  list-sync-completed          List completed sync operations"
  echo "  list-publish-completed       List completed publish operations"
  echo "  list-sync-skipped            List skipped sync operations"
  echo "  list-publish-skipped         List skipped publish operations"
  echo "  clear-all                    Clear all progress tracking"
  echo "  clear-completed              Clear completed operations (keep pending, in progress, failed, and skipped)"
  exit 1
fi

COMMAND=$1
shift

case "$COMMAND" in
  summary)
    echo "Progress Summary:"
    echo "----------------"
    echo "Total operations: 10 (70% complete)"
    echo "Pending: 1"
    echo "In Progress: 0"
    echo "Completed: 3"
    echo "Skipped: 4"
    echo "Failed: 2"
    ;;
  list-sync-failed)
    echo "Failed sync operations:"
    echo "- failed-module-1"
    echo "- failed-module-2"
    ;;
  list-publish-failed)
    echo "Failed publish operations:"
    echo "- failed-sdk-1"
    echo "- failed-sdk-2"
    ;;
  list-sync-skipped)
    echo "Skipped sync operations:"
    echo "- skipped-module-1"
    echo "- skipped-module-2"
    ;;
  list-publish-skipped)
    echo "Skipped publish operations:"
    echo "- skipped-sdk-1"
    echo "- skipped-sdk-2"
    ;;
  list-sync-pending)
    echo "Pending sync operations:"
    echo "- pending-module-1"
    ;;
  list-publish-pending)
    echo "Pending publish operations:"
    echo "- pending-sdk-1"
    ;;
  list-sync-completed)
    echo "Completed sync operations:"
    echo "- completed-module-1"
    ;;
  list-publish-completed)
    echo "Completed publish operations:"
    echo "- completed-sdk-1"
    ;;
  clear-all)
    echo "Progress tracking has been reset"
    ;;
  clear-completed)
    echo "Completed operations have been cleared"
    ;;
  *)
    echo "Error: Unknown command '$COMMAND'" >&2
    exit 1
    ;;
esac

exit 0
EOF

  # Make all mock scripts executable
  chmod +x "$test_dir/scripts/"*.sh
}

# Function to get the appropriate script path for testing
get_script_path() {
  local script_name="$1"
  local test_dir="$2"
  local script_path=""
  
  # First check if we have a mock in the test directory
  if [ -f "$test_dir/scripts/$script_name" ]; then
    script_path="$test_dir/scripts/$script_name"
  # Then try the actual script locations
  elif [ -f "$SCRIPTS_DIR/$script_name" ]; then
    script_path="$SCRIPTS_DIR/$script_name"
  elif [ -f "$REPO_ROOT/scripts/$script_name" ]; then
    script_path="$REPO_ROOT/scripts/$script_name"
  elif [ -f "../scripts/$script_name" ]; then
    script_path="../scripts/$script_name"
  else
    # Just return a path that we can use for testing even if it doesn't exist
    script_path="$test_dir/scripts/$script_name"
    echo "Warning: Creating placeholder for $script_name" >&2
    mkdir -p "$(dirname "$script_path")"
    echo "echo 'Mock $script_name for testing'" > "$script_path"
    chmod +x "$script_path"
  fi
  
  echo "$script_path"
}