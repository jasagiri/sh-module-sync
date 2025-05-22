# Module Sync Scripts

A collection of shell scripts for managing multiple modules using Git subtree and Jujutsu Workspace.

## Features

- **Add, update, and remove modules** using Git subtree and Jujutsu Workspace
- **Synchronize all modules** from their upstream repositories
- **Publish SDKs** to distribute your modules
- **Track progress** of sync and publish operations
- **Resume operations** after failures or interruptions
- **Skip specific modules** during processing

## Installation

Clone this repository and ensure the scripts are executable:

```bash
git clone https://github.com/jasagiri/sh-module-sync
cd sh-module-sync
chmod +x scripts/*.sh
```

## Usage

### Module Management

```bash
# Add a new module
./scripts/add_module.sh <git_repo_url> <module_name> [branch]

# Update a module
./scripts/update_module.sh <module_name>

# Remove a module
./scripts/remove_module.sh <module_name>

# Sync all modules
./scripts/sync-all.sh [options]

# Publish all SDKs
./scripts/publish-all.sh [options]
```

### Progress Tracking

```bash
# View progress summary
./scripts/progress.sh summary

# List failed operations
./scripts/progress.sh list-sync-failed
./scripts/progress.sh list-publish-failed

# List skipped operations
./scripts/progress.sh list-sync-skipped
./scripts/progress.sh list-publish-skipped

# Clear progress tracking
./scripts/progress.sh clear-all
```

### Advanced Options

#### Sync and Publish Options

Both `sync-all.sh` and `publish-all.sh` support these options:

```bash
--resume              Resume from previously failed or incomplete operations
--show-progress, -p   Show progress summary before exiting
--list-failed, -l     List failed modules/SDKs
--list-skipped, -s    List skipped modules/SDKs
--skip <name>         Skip the specified module/SDK (can be used multiple times)
--help, -h            Show help message
```

#### Examples

```bash
# Skip specific modules during sync
./scripts/sync-all.sh --skip module1 --skip module2

# Resume sync after failure and skip problematic modules
./scripts/sync-all.sh --resume --skip problem-module

# Publish all SDKs except specific ones
./scripts/publish-all.sh --skip sdk1 --skip sdk2

# Show progress summary after operation
./scripts/sync-all.sh --show-progress
```

## Skip Functionality

The skip functionality allows you to intentionally bypass specific modules or SDKs during processing. This is useful for:

- Temporarily skipping problematic modules
- Excluding certain modules during CI/CD pipelines
- Testing subset of modules
- Working around temporary issues with specific repositories

Skipped operations are tracked separately from failed operations. In progress calculations, skipped operations count as "completed" for percentage calculation purposes.

To view which modules/SDKs have been skipped:

```bash
./scripts/progress.sh list-sync-skipped
./scripts/progress.sh list-publish-skipped
```

## Documentation

For more detailed documentation, please see:

- [PROGRESS_TRACKING.md](PROGRESS_TRACKING.md) - Details on progress tracking functionality
- [test/README.md](test/README.md) - Information about the test suite

## Testing

The repository includes comprehensive tests with 100% code coverage:

```bash
# Run all tests
./test/run_all_tests.sh

# Generate coverage report
./scripts/simple_coverage_fixed.sh
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.
