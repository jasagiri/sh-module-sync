#!/usr/bin/env bash
set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration utilities
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/progress.sh"

# Check for command line options
RESUME=false
SHOW_PROGRESS=false
LIST_FAILED=false
LIST_SKIPPED=false
SKIP_SDKS=""

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
    --help|-h)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --resume              Resume from previously failed or incomplete operations"
      echo "  --show-progress, -p   Show progress summary before exiting"
      echo "  --list-failed, -l     List failed SDKs"
      echo "  --list-skipped, -s    List skipped SDKs"
      echo "  --skip <sdk_name>     Skip the specified SDK (can be used multiple times)"
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

# List failed SDKs if requested
if [ "$LIST_FAILED" = true ]; then
  failed_sdks=$(get_failed_operations "publish")
  if [ -z "$failed_sdks" ]; then
    echo "No failed SDKs found"
  else
    echo "Failed SDKs:"
    echo "$failed_sdks" | while read -r sdk; do
      echo "- $sdk"
    done
  fi
  exit 0
fi

# List skipped SDKs if requested
if [ "$LIST_SKIPPED" = true ]; then
  skipped_sdks=$(get_skipped_operations "publish")
  if [ -z "$skipped_sdks" ]; then
    echo "No skipped SDKs found"
  else
    echo "Skipped SDKs:"
    echo "$skipped_sdks" | while read -r sdk; do
      echo "- $sdk"
    done
  fi
  exit 0
fi

# Choose which SDKs to publish
if [ "$RESUME" = true ]; then
  # Get failed and pending SDKs only
  failed_sdks=$(get_failed_operations "publish")
  pending_sdks=$(get_pending_operations "publish")
  
  # Combine and remove duplicates
  SDKS=()
  if [ -n "$failed_sdks" ]; then
    while read -r sdk; do
      SDKS+=("$sdk")
    done <<< "$failed_sdks"
  fi
  
  if [ -n "$pending_sdks" ]; then
    while read -r sdk; do
      # Only add if not already in the array
      if ! printf '%s\n' "${SDKS[@]}" | grep -q "^$sdk$"; then
        SDKS+=("$sdk")
      fi
    done <<< "$pending_sdks"
  fi
  
  if [ ${#SDKS[@]} -eq 0 ]; then
    echo "No failed or pending SDKs to resume. Use without --resume to publish all SDKs."
    exit 0
  fi
  
  echo "Resuming publishing for ${#SDKS[@]} SDKs..."
else
  # Get all SDKs from config
  readarray -t SDKS < <(get_sdk_names)
  
  # Check if SDKs were found
  if [ ${#SDKS[@]} -eq 0 ]; then
    echo "No SDKs found in config. Please check ${SDKS_CONFIG}" >&2
    exit 1
  fi
  
  # Initialize progress tracking for all SDKs
  for sdk in "${SDKS[@]}"; do
    start_publish_tracking "${sdk}"
  done
fi

# Track overall success
PUBLISH_SUCCESS=true

# Publish each SDK
for sdk in "${SDKS[@]}"; do
  # Check if SDK should be skipped
  if should_skip "$sdk"; then
    echo "Skipping ${sdk}..."
    publish_skipped "${sdk}"
    continue
  fi

  echo "Publishing ${sdk}..."
  
  # Update progress status
  publish_in_progress "${sdk}"
  
  # Get SDK path from config
  sdk_path=$(get_sdk_path "${sdk}")
  
  # Use the path from config or fallback to name if not set
  if [ -z "$sdk_path" ]; then
    sdk_path="${sdk}"
  fi
  
  # Try to publish the SDK
  if (
    pushd "${sdk_path}" > /dev/null
    nimble publish
    popd > /dev/null
  ); then
    echo "✅ ${sdk} published successfully"
    publish_completed "${sdk}"
  else
    echo "[ERROR] Failed to publish ${sdk}" >&2
    publish_failed "${sdk}"
    PUBLISH_SUCCESS=false
    # Continue with other SDKs instead of exiting
  fi
done

# Show final status
if [ "$PUBLISH_SUCCESS" = true ]; then
  echo "🎉 All SDKs published successfully"
else
  echo "⚠️ Some SDKs failed to publish. Use --resume to retry or --list-failed to see which ones."
  # Return non-zero exit code on failure
  # But only for SDKs that actually failed, not skipped ones
  failed_count=$(get_failed_operations "publish" | wc -l)
  if [ "$failed_count" -gt 0 ]; then
    exit 1
  fi
fi

# Show progress summary if requested
if [ "$SHOW_PROGRESS" = true ]; then
  print_progress_summary
fi