#!/usr/bin/env bash
# Progress management utility

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load progress tracking utilities
source "${SCRIPT_DIR}/lib/progress.sh"

# Display usage information
show_usage() {
  cat << EOF
Usage: $0 <command> [arguments]

Progress Commands:
  summary                      Show progress summary
  list-sync-failed             List failed sync operations
  list-publish-failed          List failed publish operations
  list-sync-pending            List pending sync operations
  list-publish-pending         List pending publish operations
  list-sync-completed          List completed sync operations
  list-publish-completed       List completed publish operations
  list-sync-skipped            List skipped sync operations
  list-publish-skipped         List skipped publish operations
  clear-all                    Clear all progress tracking
  clear-completed              Clear completed operations (keep pending, in progress, failed, and skipped)
  
Examples:
  $0 summary
  $0 list-sync-failed
  $0 clear-completed
EOF
}

# Ensure we have the required arguments
if [ $# -lt 1 ]; then
  show_usage
  exit 1
fi

COMMAND=$1
shift

case "$COMMAND" in
  summary)
    print_progress_summary
    ;;
  list-sync-failed)
    failed_modules=$(get_failed_operations "$OP_SYNC")
    if [ -z "$failed_modules" ]; then
      echo "No failed sync operations found"
    else
      echo "Failed sync operations:"
      echo "$failed_modules" | while read -r module; do
        echo "- $module"
      done
    fi
    ;;
  list-publish-failed)
    failed_sdks=$(get_failed_operations "$OP_PUBLISH")
    if [ -z "$failed_sdks" ]; then
      echo "No failed publish operations found"
    else
      echo "Failed publish operations:"
      echo "$failed_sdks" | while read -r sdk; do
        echo "- $sdk"
      done
    fi
    ;;
  list-sync-pending)
    pending_modules=$(get_pending_operations "$OP_SYNC")
    if [ -z "$pending_modules" ]; then
      echo "No pending sync operations found"
    else
      echo "Pending sync operations:"
      echo "$pending_modules" | while read -r module; do
        echo "- $module"
      done
    fi
    ;;
  list-publish-pending)
    pending_sdks=$(get_pending_operations "$OP_PUBLISH")
    if [ -z "$pending_sdks" ]; then
      echo "No pending publish operations found"
    else
      echo "Pending publish operations:"
      echo "$pending_sdks" | while read -r sdk; do
        echo "- $sdk"
      done
    fi
    ;;
  list-sync-completed)
    completed_modules=$(get_completed_operations "$OP_SYNC")
    if [ -z "$completed_modules" ]; then
      echo "No completed sync operations found"
    else
      echo "Completed sync operations:"
      echo "$completed_modules" | while read -r module; do
        echo "- $module"
      done
    fi
    ;;
  list-publish-completed)
    completed_sdks=$(get_completed_operations "$OP_PUBLISH")
    if [ -z "$completed_sdks" ]; then
      echo "No completed publish operations found"
    else
      echo "Completed publish operations:"
      echo "$completed_sdks" | while read -r sdk; do
        echo "- $sdk"
      done
    fi
    ;;
  list-sync-skipped)
    skipped_modules=$(get_skipped_operations "$OP_SYNC")
    if [ -z "$skipped_modules" ]; then
      echo "No skipped sync operations found"
    else
      echo "Skipped sync operations:"
      echo "$skipped_modules" | while read -r module; do
        echo "- $module"
      done
    fi
    ;;
  list-publish-skipped)
    skipped_sdks=$(get_skipped_operations "$OP_PUBLISH")
    if [ -z "$skipped_sdks" ]; then
      echo "No skipped publish operations found"
    else
      echo "Skipped publish operations:"
      echo "$skipped_sdks" | while read -r sdk; do
        echo "- $sdk"
      done
    fi
    ;;
  clear-all)
    clear_progress
    ;;
  clear-completed)
    clear_completed_operations
    ;;
  *)
    echo "Error: Unknown command '$COMMAND'" >&2
    show_usage
    exit 1
    ;;
esac

exit 0