#!/usr/bin/env bash
# Configuration management utility

set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration utilities
source "${SCRIPT_DIR}/lib/config.sh"

# Display usage information
show_usage() {
  cat << EOF
Usage: $0 <command> [arguments]

Configuration Commands:
  list-modules                  List all configured modules
  list-sdks                     List all configured SDKs
  add-module <name> <repo_url> [branch]  Add a new module to the config
  remove-module <name>          Remove a module from the config
  add-sdk <name> <path> [version]        Add a new SDK to the config
  remove-sdk <name>             Remove an SDK from the config

Examples:
  $0 list-modules
  $0 add-module new-module https://github.com/example/new-module.git develop
  $0 remove-module old-module
  $0 list-sdks
  $0 add-sdk custom-sdk ./custom-sdk 1.0.0
EOF
}

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# Handle command
if [ $# -lt 1 ]; then
  show_usage
  exit 1
fi

COMMAND=$1
shift

case "$COMMAND" in
  list-modules)
    list_modules
    ;;
  list-sdks)
    list_sdks
    ;;
  add-module)
    if [ $# -lt 2 ]; then
      echo "Error: Missing required arguments for add-module" >&2
      echo "Usage: $0 add-module <name> <repo_url> [branch]" >&2
      exit 1
    fi
    NAME=$1
    REPO_URL=$2
    BRANCH=${3:-main}
    
    add_module_to_config "$NAME" "$REPO_URL" "$BRANCH"
    echo "✅ Added module '$NAME' to configuration"
    ;;
  remove-module)
    if [ $# -lt 1 ]; then
      echo "Error: Missing module name for remove-module" >&2
      echo "Usage: $0 remove-module <name>" >&2
      exit 1
    fi
    NAME=$1
    
    remove_module_from_config "$NAME"
    echo "✅ Removed module '$NAME' from configuration"
    ;;
  add-sdk)
    if [ $# -lt 2 ]; then
      echo "Error: Missing required arguments for add-sdk" >&2
      echo "Usage: $0 add-sdk <name> <path> [version]" >&2
      exit 1
    fi
    NAME=$1
    PATH=$2
    VERSION=${3:-0.1.0}
    
    add_sdk_to_config "$NAME" "$PATH" "$VERSION"
    echo "✅ Added SDK '$NAME' to configuration"
    ;;
  remove-sdk)
    if [ $# -lt 1 ]; then
      echo "Error: Missing SDK name for remove-sdk" >&2
      echo "Usage: $0 remove-sdk <name>" >&2
      exit 1
    fi
    NAME=$1
    
    remove_sdk_from_config "$NAME"
    echo "✅ Removed SDK '$NAME' from configuration"
    ;;
  *)
    echo "Error: Unknown command '$COMMAND'" >&2
    show_usage
    exit 1
    ;;
esac

exit 0