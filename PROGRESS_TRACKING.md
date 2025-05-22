# Progress Tracking for Module Management

This document provides an overview of the progress tracking feature and how to use it.

## Overview

The progress tracking system allows you to:

1. Track the status of module synchronization and SDK publication operations
2. Resume operations that failed or were interrupted
3. Skip specific modules or SDKs as needed
4. Get detailed reports on the progress of operations
5. Monitor which modules/SDKs have completed, which are in progress, and which have failed or been skipped

## Progress States

Operations can be in one of the following states:

- **pending**: The operation has been queued but not started
- **in_progress**: The operation is currently running
- **completed**: The operation completed successfully
- **failed**: The operation failed
- **skipped**: The operation was intentionally skipped

## Using Progress Tracking

### Syncing Modules with Progress Tracking

```bash
# Sync all modules
./scripts/sync-all.sh

# Show progress summary after syncing
./scripts/sync-all.sh --show-progress

# Resume only failed and pending operations
./scripts/sync-all.sh --resume

# List failed modules and exit
./scripts/sync-all.sh --list-failed

# List skipped modules and exit
./scripts/sync-all.sh --list-skipped

# Skip specific modules
./scripts/sync-all.sh --skip module1 --skip module2

# Show help
./scripts/sync-all.sh --help
```

### Publishing SDKs with Progress Tracking

```bash
# Publish all SDKs
./scripts/publish-all.sh

# Show progress summary after publishing
./scripts/publish-all.sh --show-progress

# Resume only failed and pending operations
./scripts/publish-all.sh --resume

# List failed SDKs and exit
./scripts/publish-all.sh --list-failed

# List skipped SDKs and exit
./scripts/publish-all.sh --list-skipped

# Skip specific SDKs
./scripts/publish-all.sh --skip sdk1 --skip sdk2

# Show help
./scripts/publish-all.sh --help
```

### Managing Progress with the Progress Utility

```bash
# Show overall progress summary
./scripts/progress.sh summary

# List failed operations
./scripts/progress.sh list-sync-failed
./scripts/progress.sh list-publish-failed

# List pending operations
./scripts/progress.sh list-sync-pending
./scripts/progress.sh list-publish-pending

# List completed operations
./scripts/progress.sh list-sync-completed
./scripts/progress.sh list-publish-completed

# List skipped operations
./scripts/progress.sh list-sync-skipped
./scripts/progress.sh list-publish-skipped

# Clear all progress tracking
./scripts/progress.sh clear-all

# Clear only completed operations (keep pending, in progress, failed, and skipped)
./scripts/progress.sh clear-completed
```

## Technical Implementation

### Storage

Progress is stored in a JSON file at `build/progress.json` with the following structure:

```json
{
  "operations": [
    {
      "type": "sync",
      "name": "module-name",
      "status": "completed",
      "created_at": "2025-05-20T12:00:00+0000",
      "updated_at": "2025-05-20T12:01:00+0000",
      "started_at": "2025-05-20T12:00:10+0000",
      "completed_at": "2025-05-20T12:01:00+0000"
    },
    {
      "type": "publish",
      "name": "sdk-name",
      "status": "skipped",
      "created_at": "2025-05-20T12:30:00+0000",
      "updated_at": "2025-05-20T12:31:00+0000",
      "started_at": null,
      "completed_at": "2025-05-20T12:31:00+0000"
    }
  ]
}
```

### Library Functions

The progress tracking functionality is provided by `scripts/lib/progress.sh` and includes:

- Functions for tracking sync operations: `start_sync_tracking`, `sync_in_progress`, `sync_completed`, `sync_failed`, `sync_skipped`
- Functions for tracking publish operations: `start_publish_tracking`, `publish_in_progress`, `publish_completed`, `publish_failed`, `publish_skipped`
- Functions for querying progress: `get_operation_status`, `get_operations_by_status`, `get_pending_operations`, `get_in_progress_operations`, `get_completed_operations`, `get_failed_operations`, `get_skipped_operations`
- Functions for managing progress: `clear_progress`, `clear_completed_operations`

## Completion Percentage Calculation

When calculating completion percentages:

- **Completed** operations count as complete
- **Skipped** operations also count as complete (for percentage calculation)
- **Failed** operations count as incomplete
- **Pending** operations count as incomplete
- **In Progress** operations count as incomplete

This means that if you skip a module, the overall completion percentage will still increase accordingly.

## Exit Codes

When running scripts with progress tracking:

- A non-zero exit code is returned if any operation **failed** (status = failed)
- A zero exit code is returned if all operations completed successfully or were skipped
- This allows you to use the scripts in larger automation pipelines while ignoring skipped modules

## Extending Progress Tracking

You can add progress tracking to other scripts by:

1. Sourcing the progress library: `source "${SCRIPT_DIR}/lib/progress.sh"`
2. Using the tracking functions to record operation status
3. Using the query functions to check operation status

## Error Handling

The progress tracking system includes fallback methods when jq is not available, though functionality will be limited:

- Basic tracking and status updates work without jq
- Advanced queries and summaries require jq
- If jq is not available, status updates will be simplified and may not include accurate timestamps

## Skipping Operations

The progress tracking system supports explicitly skipping operations that you don't want to run. This is useful for:

- **Temporarily excluding problematic modules**: If a specific module is causing issues, you can skip it to complete other operations
- **CI/CD environments**: You may want to skip certain modules in specific environments
- **Testing workflows**: Skip some modules to focus on testing others
- **Partial deployments**: When you want to sync or publish only a subset of modules

### Using the Skip Functionality

To skip modules during sync:
```bash
./scripts/sync-all.sh --skip module1 --skip module2
```

To skip SDKs during publish:
```bash
./scripts/publish-all.sh --skip sdk1 --skip sdk2
```

You can also combine skip with other options:
```bash
# Resume operations but skip problematic modules
./scripts/sync-all.sh --resume --skip problem-module --show-progress
```

### How Skipping Works

1. When you use the `--skip` option, the specified module/SDK is marked with a `skipped` status
2. The script continues to the next module/SDK without attempting to sync or publish the skipped one
3. In the progress calculation, skipped items count as "completed" (for percentage calculation)
4. Skipped operations are tracked separately from failed operations
5. Exit codes are not affected by skipped operations (only by failed ones)

### Checking Skipped Operations

To see which operations have been skipped:
```bash
# Show all skipped modules
./scripts/progress.sh list-sync-skipped

# Show all skipped SDKs
./scripts/progress.sh list-publish-skipped

# See skipped operations in the summary
./scripts/progress.sh summary
```

## Testing

The progress tracking system includes comprehensive tests:

- `test/test_progress.sh`: Tests basic progress tracking functionality
- `test/test_skip_functionality.sh`: Tests the skip functionality
- Mock tests for verifying skip options in the CLI

The tests verify:
- Initialization of progress tracking
- Status tracking for operations (including skipped status)
- Percentage calculation with skipped operations
- Clearing operations
- CLI options for skipping operations