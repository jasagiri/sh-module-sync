#!/usr/bin/env bash
# Progress tracking utilities for the module-sync scripts

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Create build directory if it doesn't exist
BUILD_DIR="${REPO_ROOT}/build"
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

# Function to initialize progress tracking
init_progress_tracking() {
  # Create an empty progress file if it doesn't exist
  if [ ! -f "$PROGRESS_FILE" ]; then
    echo '{"operations": []}' > "$PROGRESS_FILE"
  fi
}

# Function to get current timestamp
get_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z"
}

# Function to start tracking a sync operation
start_sync_tracking() {
  local module_name="$1"
  
  if [ -z "$module_name" ]; then
    echo "Error: Module name is required for tracking" >&2
    return 1
  fi
  
  init_progress_tracking
  add_operation "$OP_SYNC" "$module_name" "$STATUS_PENDING"
}

# Function to start tracking a publish operation
start_publish_tracking() {
  local sdk_name="$1"
  
  if [ -z "$sdk_name" ]; then
    echo "Error: SDK name is required for tracking" >&2
    return 1
  fi
  
  init_progress_tracking
  add_operation "$OP_PUBLISH" "$sdk_name" "$STATUS_PENDING"
}

# Function to add an operation to the progress file
add_operation() {
  local op_type="$1"
  local name="$2"
  local status="$3"
  local timestamp=$(get_timestamp)
  
  # Check if operation already exists
  if operation_exists "$op_type" "$name"; then
    update_operation_status "$op_type" "$name" "$status"
    return
  fi
  
  if command -v jq &> /dev/null; then
    # Add operation using jq
    jq --arg type "$op_type" \
       --arg name "$name" \
       --arg status "$status" \
       --arg timestamp "$timestamp" \
       '.operations += [{
         "type": $type,
         "name": $name,
         "status": $status,
         "created_at": $timestamp,
         "updated_at": $timestamp,
         "started_at": null,
         "completed_at": null
       }]' \
       "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
  else
    # Manual addition (basic approach)
    # Remove the closing bracket
    sed -i.bak 's/]}$/,/g' "$PROGRESS_FILE"
    # Add the new operation and close the JSON
    echo '{
      "type": "'"$op_type"'",
      "name": "'"$name"'",
      "status": "'"$status"'",
      "created_at": "'"$timestamp"'",
      "updated_at": "'"$timestamp"'",
      "started_at": null,
      "completed_at": null
    }]}' >> "$PROGRESS_FILE"
    rm -f "${PROGRESS_FILE}.bak"
  fi
}

# Function to check if an operation exists
operation_exists() {
  local op_type="$1"
  local name="$2"
  
  if command -v jq &> /dev/null; then
    local count=$(jq --arg type "$op_type" --arg name "$name" \
      '.operations | map(select(.type == $type and .name == $name)) | length' \
      "$PROGRESS_FILE")
    [ "$count" -gt 0 ]
  else
    grep -q "\"type\": *\"$op_type\"" "$PROGRESS_FILE" && grep -q "\"name\": *\"$name\"" "$PROGRESS_FILE"
  fi
}

# Function to update operation status
update_operation_status() {
  local op_type="$1"
  local name="$2"
  local status="$3"
  local timestamp=$(get_timestamp)
  
  if command -v jq &> /dev/null; then
    local tempfile="${PROGRESS_FILE}.tmp"
    
    # Set started_at timestamp if moving to in_progress
    if [ "$status" = "$STATUS_IN_PROGRESS" ]; then
      jq --arg type "$op_type" \
         --arg name "$name" \
         --arg status "$status" \
         --arg timestamp "$timestamp" \
         '.operations = [.operations[] | 
           if .type == $type and .name == $name then 
             . + {"status": $status, "updated_at": $timestamp, "started_at": $timestamp} 
           else 
             . 
           end]' \
         "$PROGRESS_FILE" > "$tempfile" && mv "$tempfile" "$PROGRESS_FILE"
    # Set completed_at timestamp if completing, failing or skipping
    elif [ "$status" = "$STATUS_COMPLETED" ] || [ "$status" = "$STATUS_FAILED" ] || [ "$status" = "$STATUS_SKIPPED" ]; then
      jq --arg type "$op_type" \
         --arg name "$name" \
         --arg status "$status" \
         --arg timestamp "$timestamp" \
         '.operations = [.operations[] | 
           if .type == $type and .name == $name then 
             . + {"status": $status, "updated_at": $timestamp, "completed_at": $timestamp} 
           else 
             . 
           end]' \
         "$PROGRESS_FILE" > "$tempfile" && mv "$tempfile" "$PROGRESS_FILE"
    else
      # Regular status update
      jq --arg type "$op_type" \
         --arg name "$name" \
         --arg status "$status" \
         --arg timestamp "$timestamp" \
         '.operations = [.operations[] | 
           if .type == $type and .name == $name then 
             . + {"status": $status, "updated_at": $timestamp} 
           else 
             . 
           end]' \
         "$PROGRESS_FILE" > "$tempfile" && mv "$tempfile" "$PROGRESS_FILE"
    fi
  else
    # Simple approach without jq (just indicating status change)
    echo "Warning: Using simplified tracking without jq. Status updated but timestamps may not be accurate." >&2
    local temp_file="${PROGRESS_FILE}.tmp"
    cat "$PROGRESS_FILE" | sed "s/\"status\": *\"[^\"]*\"/\"status\": \"$status\"/" > "$temp_file"
    mv "$temp_file" "$PROGRESS_FILE"
  fi
}

# Mark sync operation as in progress
sync_in_progress() {
  local module_name="$1"
  update_operation_status "$OP_SYNC" "$module_name" "$STATUS_IN_PROGRESS"
}

# Mark sync operation as completed
sync_completed() {
  local module_name="$1"
  update_operation_status "$OP_SYNC" "$module_name" "$STATUS_COMPLETED"
}

# Mark sync operation as failed
sync_failed() {
  local module_name="$1"
  update_operation_status "$OP_SYNC" "$module_name" "$STATUS_FAILED"
}

# Mark sync operation as skipped
sync_skipped() {
  local module_name="$1"
  update_operation_status "$OP_SYNC" "$module_name" "$STATUS_SKIPPED"
}

# Mark publish operation as in progress
publish_in_progress() {
  local sdk_name="$1"
  update_operation_status "$OP_PUBLISH" "$sdk_name" "$STATUS_IN_PROGRESS"
}

# Mark publish operation as completed
publish_completed() {
  local sdk_name="$1"
  update_operation_status "$OP_PUBLISH" "$sdk_name" "$STATUS_COMPLETED"
}

# Mark publish operation as failed
publish_failed() {
  local sdk_name="$1"
  update_operation_status "$OP_PUBLISH" "$sdk_name" "$STATUS_FAILED"
}

# Mark publish operation as skipped
publish_skipped() {
  local sdk_name="$1"
  update_operation_status "$OP_PUBLISH" "$sdk_name" "$STATUS_SKIPPED"
}

# Get operation status
get_operation_status() {
  local op_type="$1"
  local name="$2"
  
  if command -v jq &> /dev/null; then
    jq -r --arg type "$op_type" --arg name "$name" \
      '.operations[] | select(.type == $type and .name == $name) | .status' \
      "$PROGRESS_FILE" 2>/dev/null
  else
    # This is a simplistic approach that might not work for all cases
    # More robust parsing would require a complex shell script
    grep -A10 "\"type\": *\"$op_type\"" "$PROGRESS_FILE" | 
      grep -A5 "\"name\": *\"$name\"" | 
      grep "\"status\": *\"[^\"]*\"" | 
      head -n1 | 
      sed 's/.*"status": *"\([^"]*\)".*/\1/'
  fi
}

# Get all operations with a specific status
get_operations_by_status() {
  local op_type="$1"
  local status="$2"
  
  if command -v jq &> /dev/null; then
    jq -r --arg type "$op_type" --arg status "$status" \
      '.operations[] | select(.type == $type and .status == $status) | .name' \
      "$PROGRESS_FILE" 2>/dev/null
  else
    # Very simplified approach
    grep -B10 "\"status\": *\"$status\"" "$PROGRESS_FILE" | 
      grep -B5 "\"type\": *\"$op_type\"" | 
      grep "\"name\": *\"[^\"]*\"" | 
      sed 's/.*"name": *"\([^"]*\)".*/\1/'
  fi
}

# Get pending operations
get_pending_operations() {
  local op_type="$1"
  get_operations_by_status "$op_type" "$STATUS_PENDING"
}

# Get in progress operations
get_in_progress_operations() {
  local op_type="$1"
  get_operations_by_status "$op_type" "$STATUS_IN_PROGRESS"
}

# Get completed operations
get_completed_operations() {
  local op_type="$1"
  get_operations_by_status "$op_type" "$STATUS_COMPLETED"
}

# Get failed operations
get_failed_operations() {
  local op_type="$1"
  get_operations_by_status "$op_type" "$STATUS_FAILED"
}

# Get skipped operations
get_skipped_operations() {
  local op_type="$1"
  get_operations_by_status "$op_type" "$STATUS_SKIPPED"
}

# Clear all operations (reset progress)
clear_progress() {
  echo '{"operations": []}' > "$PROGRESS_FILE"
  echo "Progress tracking has been reset"
}

# Clear completed operations (keep pending, in_progress, failed and skipped)
clear_completed_operations() {
  if command -v jq &> /dev/null; then
    jq '.operations = [.operations[] | select(.status != "completed")]' \
      "$PROGRESS_FILE" > "${PROGRESS_FILE}.tmp" && mv "${PROGRESS_FILE}.tmp" "$PROGRESS_FILE"
    echo "Completed operations have been cleared"
  else
    echo "Error: jq is required to clear completed operations" >&2
    return 1
  fi
}

# Print progress summary
print_progress_summary() {
  init_progress_tracking
  
  if command -v jq &> /dev/null; then
    local total=$(jq '.operations | length' "$PROGRESS_FILE")
    local pending=$(jq --arg status "$STATUS_PENDING" '.operations | map(select(.status == $status)) | length' "$PROGRESS_FILE")
    local in_progress=$(jq --arg status "$STATUS_IN_PROGRESS" '.operations | map(select(.status == $status)) | length' "$PROGRESS_FILE")
    local completed=$(jq --arg status "$STATUS_COMPLETED" '.operations | map(select(.status == $status)) | length' "$PROGRESS_FILE")
    local failed=$(jq --arg status "$STATUS_FAILED" '.operations | map(select(.status == $status)) | length' "$PROGRESS_FILE")
    local skipped=$(jq --arg status "$STATUS_SKIPPED" '.operations | map(select(.status == $status)) | length' "$PROGRESS_FILE")
    
    local sync_total=$(jq --arg type "$OP_SYNC" '.operations | map(select(.type == $type)) | length' "$PROGRESS_FILE")
    local sync_completed=$(jq --arg type "$OP_SYNC" --arg status "$STATUS_COMPLETED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    local sync_failed=$(jq --arg type "$OP_SYNC" --arg status "$STATUS_FAILED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    local sync_skipped=$(jq --arg type "$OP_SYNC" --arg status "$STATUS_SKIPPED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    
    local publish_total=$(jq --arg type "$OP_PUBLISH" '.operations | map(select(.type == $type)) | length' "$PROGRESS_FILE")
    local publish_completed=$(jq --arg type "$OP_PUBLISH" --arg status "$STATUS_COMPLETED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    local publish_failed=$(jq --arg type "$OP_PUBLISH" --arg status "$STATUS_FAILED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    local publish_skipped=$(jq --arg type "$OP_PUBLISH" --arg status "$STATUS_SKIPPED" '.operations | map(select(.type == $type and .status == $status)) | length' "$PROGRESS_FILE")
    
    # Calculate completion percentages (counting skipped as completed for percentage calculation)
    local sync_percent=0
    local publish_percent=0
    local total_percent=0
    
    if [ "$sync_total" -gt 0 ]; then
      local sync_effective_completed=$((sync_completed + sync_skipped))
      sync_percent=$((sync_effective_completed * 100 / sync_total))
    fi
    
    if [ "$publish_total" -gt 0 ]; then
      local publish_effective_completed=$((publish_completed + publish_skipped))
      publish_percent=$((publish_effective_completed * 100 / publish_total))
    fi
    
    if [ "$total" -gt 0 ]; then
      local total_effective_completed=$((completed + skipped))
      total_percent=$((total_effective_completed * 100 / total))
    fi
    
    # Print summary
    echo "Progress Summary:"
    echo "----------------"
    echo "Total operations: $total ($total_percent% complete)"
    echo "Pending: $pending"
    echo "In Progress: $in_progress"
    echo "Completed: $completed"
    echo "Skipped: $skipped"
    echo "Failed: $failed"
    echo ""
    echo "Sync operations: $sync_total ($sync_percent% complete, $sync_failed failed, $sync_skipped skipped)"
    echo "Publish operations: $publish_total ($publish_percent% complete, $publish_failed failed, $publish_skipped skipped)"
    
    # List failed operations
    if [ "$failed" -gt 0 ]; then
      echo ""
      echo "Failed operations:"
      jq -r --arg status "$STATUS_FAILED" '.operations[] | select(.status == $status) | "- " + .type + ": " + .name' "$PROGRESS_FILE"
    fi
    
    # List skipped operations
    if [ "$skipped" -gt 0 ]; then
      echo ""
      echo "Skipped operations:"
      jq -r --arg status "$STATUS_SKIPPED" '.operations[] | select(.status == $status) | "- " + .type + ": " + .name' "$PROGRESS_FILE"
    fi
  else
    echo "Progress summary unavailable without jq"
    echo "Please install jq for more detailed progress tracking"
  fi
}

# Export the functions
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
export -f get_operation_status
export -f get_operations_by_status
export -f get_pending_operations
export -f get_in_progress_operations
export -f get_completed_operations
export -f get_failed_operations
export -f get_skipped_operations
export -f clear_progress
export -f clear_completed_operations
export -f print_progress_summary