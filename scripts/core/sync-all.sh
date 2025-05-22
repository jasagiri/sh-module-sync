#!/usr/bin/env bash
set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"

# Load configuration utilities
source "${PARENT_DIR}/lib/config.sh"
source "${PARENT_DIR}/lib/progress.sh"

# Check for command line options
RESUME=false
SHOW_PROGRESS=false
LIST_FAILED=false
LIST_SKIPPED=false
SKIP_MODULES=""

# Process command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      RESUME=true
      shift
      ;;
    --show-progress|-p)
      SHOW_PROGRESS=true
      shift
      ;;
    --list-failed|-l)
      LIST_FAILED=true
      shift
      ;;
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
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --resume              Resume from previously failed or incomplete operations"
      echo "  --show-progress, -p   Show progress summary before exiting"
      echo "  --list-failed, -l     List failed modules"
      echo "  --list-skipped, -s    List skipped modules"
      echo "  --skip <module_name>  Skip the specified module (can be used multiple times)"
      echo "  --help, -h            Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help to see available options" >&2
      exit 1
      ;;
  esac
done

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

# List failed modules if requested
if [ "$LIST_FAILED" = true ]; then
  failed_modules=$(get_failed_operations "sync")
  if [ -z "$failed_modules" ]; then
    echo "No failed modules found"
  else
    echo "Failed modules:"
    echo "$failed_modules" | while read -r module; do
      echo "- $module"
    done
  fi
  exit 0
fi

# List skipped modules if requested
if [ "$LIST_SKIPPED" = true ]; then
  skipped_modules=$(get_skipped_operations "sync")
  if [ -z "$skipped_modules" ]; then
    echo "No skipped modules found"
  else
    echo "Skipped modules:"
    echo "$skipped_modules" | while read -r module; do
      echo "- $module"
    done
  fi
  exit 0
fi

# Choose which modules to sync
if [ "$RESUME" = true ]; then
  # Get failed and pending modules only
  failed_modules=$(get_failed_operations "sync")
  pending_modules=$(get_pending_operations "sync")
  
  # Combine and remove duplicates
  MODULES=()
  if [ -n "$failed_modules" ]; then
    while read -r module; do
      MODULES+=("$module")
    done <<< "$failed_modules"
  fi
  
  if [ -n "$pending_modules" ]; then
    while read -r module; do
      # Only add if not already in the array
      if ! printf '%s\n' "${MODULES[@]}" | grep -q "^$module$"; then
        MODULES+=("$module")
      fi
    done <<< "$pending_modules"
  fi
  
  if [ ${#MODULES[@]} -eq 0 ]; then
    echo "No failed or pending modules to resume. Use without --resume to sync all modules."
    exit 0
  fi
  
  echo "Resuming sync for ${#MODULES[@]} modules..."
else
  # Get all modules from config
  readarray -t MODULES < <(get_module_names)
  
  # Check if modules were found
  if [ ${#MODULES[@]} -eq 0 ]; then
    echo "No modules found in config. Please check ${MODULES_CONFIG}" >&2
    exit 1
  fi
  
  # Initialize progress tracking for all modules
  for module in "${MODULES[@]}"; do
    start_sync_tracking "${module}"
  done
fi

# Track overall success
SYNC_SUCCESS=true

# Sync each module
for module in "${MODULES[@]}"; do
  # Check if module should be skipped
  if should_skip "$module"; then
    echo "Skipping ${module}..."
    sync_skipped "${module}"
    continue
  fi

  echo "Syncing ${module}..."
  
  # Update progress status
  sync_in_progress "${module}"
  
  # Try to update the module
  if "${SCRIPT_DIR}/update_module.sh" "${module}"; then
    echo "✅ ${module} synced successfully"
    sync_completed "${module}"
  else
    echo "[ERROR] Failed to sync ${module}" >&2
    sync_failed "${module}"
    SYNC_SUCCESS=false
    # Continue with other modules instead of exiting
  fi
done

# Show final status
if [ "$SYNC_SUCCESS" = true ]; then
  echo "✅ All modules synced successfully"
else
  echo "⚠️ Some modules failed to sync. Use --resume to retry or --list-failed to see which ones."
  # Return non-zero exit code on failure
  # But only for modules that actually failed, not skipped ones
  failed_count=$(get_failed_operations "sync" | wc -l)
  if [ "$failed_count" -gt 0 ]; then
    exit 1
  fi
fi

# Show progress summary if requested
if [ "$SHOW_PROGRESS" = true ]; then
  print_progress_summary
fi