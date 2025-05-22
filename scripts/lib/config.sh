#!/usr/bin/env bash
# Configuration utilities for the module-sync scripts

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_DIR="${REPO_ROOT}/config"

# Configuration files
MODULES_CONFIG="${CONFIG_DIR}/modules.json"
SDKS_CONFIG="${CONFIG_DIR}/sdks.json"

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is required but not found. Please install jq." >&2
  echo "Visit: https://stedolan.github.io/jq/download/" >&2
  # Fallback to a basic parser if jq is not available
  echo "Using fallback parser..." >&2
fi

# Function to get module names
get_module_names() {
  if command -v jq &> /dev/null; then
    jq -r '.modules[].name' "$MODULES_CONFIG" 2>/dev/null
  else
    # Fallback: Extract with grep
    grep -o '"name": *"[^"]*"' "$MODULES_CONFIG" | cut -d'"' -f4
  fi
}

# Function to get module repo URL by name
get_module_repo_url() {
  local module_name="$1"
  
  if command -v jq &> /dev/null; then
    jq -r --arg name "$module_name" '.modules[] | select(.name == $name) | .repo_url' "$MODULES_CONFIG" 2>/dev/null
  else
    # Find the module section
    local in_section=false
    local found_name=false
    
    while IFS= read -r line; do
      if [[ "$line" == *"{"* ]]; then
        in_section=true
        found_name=false
      elif [[ "$line" == *"}"* ]]; then
        in_section=false
      elif [[ "$in_section" == true && "$line" == *"\"name\""*"\"$module_name\""* ]]; then
        found_name=true
      elif [[ "$found_name" == true && "$line" == *"\"repo_url\""* ]]; then
        echo "$line" | grep -o '"repo_url": *"[^"]*"' | cut -d'"' -f4
        break
      fi
    done < "$MODULES_CONFIG"
  fi
}

# Function to get module branch by name
get_module_branch() {
  local module_name="$1"
  
  if command -v jq &> /dev/null; then
    branch=$(jq -r --arg name "$module_name" '.modules[] | select(.name == $name) | .branch' "$MODULES_CONFIG" 2>/dev/null)
    if [[ "$branch" == "null" ]]; then
      echo "main"  # Default to main if branch is not specified
    else
      echo "$branch"
    fi
  else
    # Find the module section
    local in_section=false
    local found_name=false
    local branch=""
    
    while IFS= read -r line; do
      if [[ "$line" == *"{"* ]]; then
        in_section=true
        found_name=false
      elif [[ "$line" == *"}"* ]]; then
        in_section=false
        if [[ "$found_name" == true && -z "$branch" ]]; then
          echo "main"  # Default to main if branch is not found
          return
        fi
      elif [[ "$in_section" == true && "$line" == *"\"name\""*"\"$module_name\""* ]]; then
        found_name=true
      elif [[ "$found_name" == true && "$line" == *"\"branch\""* ]]; then
        branch=$(echo "$line" | grep -o '"branch": *"[^"]*"' | cut -d'"' -f4)
        echo "$branch"
        return
      fi
    done < "$MODULES_CONFIG"
    
    # If we get here, branch wasn't found but name was matched
    if [[ "$found_name" == true ]]; then
      echo "main"  # Default to main
    fi
  fi
}

# Function to get SDK names
get_sdk_names() {
  if command -v jq &> /dev/null; then
    jq -r '.sdks[].name' "$SDKS_CONFIG" 2>/dev/null
  else
    # Fallback: Extract with grep
    grep -o '"name": *"[^"]*"' "$SDKS_CONFIG" | cut -d'"' -f4
  fi
}

# Function to get SDK path by name
get_sdk_path() {
  local sdk_name="$1"
  
  if command -v jq &> /dev/null; then
    jq -r --arg name "$sdk_name" '.sdks[] | select(.name == $name) | .path' "$SDKS_CONFIG" 2>/dev/null
  else
    # Find the SDK section
    local in_section=false
    local found_name=false
    
    while IFS= read -r line; do
      if [[ "$line" == *"{"* ]]; then
        in_section=true
        found_name=false
      elif [[ "$line" == *"}"* ]]; then
        in_section=false
      elif [[ "$in_section" == true && "$line" == *"\"name\""*"\"$sdk_name\""* ]]; then
        found_name=true
      elif [[ "$found_name" == true && "$line" == *"\"path\""* ]]; then
        echo "$line" | grep -o '"path": *"[^"]*"' | cut -d'"' -f4
        break
      fi
    done < "$SDKS_CONFIG"
  fi
}

# Function to get SDK version by name
get_sdk_version() {
  local sdk_name="$1"
  
  if command -v jq &> /dev/null; then
    jq -r --arg name "$sdk_name" '.sdks[] | select(.name == $name) | .version' "$SDKS_CONFIG" 2>/dev/null
  else
    # Find the SDK section
    local in_section=false
    local found_name=false
    
    while IFS= read -r line; do
      if [[ "$line" == *"{"* ]]; then
        in_section=true
        found_name=false
      elif [[ "$line" == *"}"* ]]; then
        in_section=false
      elif [[ "$in_section" == true && "$line" == *"\"name\""*"\"$sdk_name\""* ]]; then
        found_name=true
      elif [[ "$found_name" == true && "$line" == *"\"version\""* ]]; then
        echo "$line" | grep -o '"version": *"[^"]*"' | cut -d'"' -f4
        break
      fi
    done < "$SDKS_CONFIG"
  fi
}

# Function to add a new module to the config
add_module_to_config() {
  local name="$1"
  local repo_url="$2"
  local branch="${3:-main}"
  
  # Create config directory if it doesn't exist
  mkdir -p "$CONFIG_DIR"
  
  # Create modules config if it doesn't exist
  if [ ! -f "$MODULES_CONFIG" ]; then
    echo '{"modules": []}' > "$MODULES_CONFIG"
  fi
  
  if command -v jq &> /dev/null; then
    # Add module to config using jq
    jq --arg name "$name" \
       --arg repo_url "$repo_url" \
       --arg branch "$branch" \
       '.modules += [{"name": $name, "repo_url": $repo_url, "branch": $branch}]' \
       "$MODULES_CONFIG" > "${MODULES_CONFIG}.tmp" && mv "${MODULES_CONFIG}.tmp" "$MODULES_CONFIG"
  else
    # Manual addition (basic approach)
    # Remove the closing brackets
    sed -i.bak 's/}]}$/},{/g' "$MODULES_CONFIG"
    # Add the new module and close the JSON
    echo "\"name\": \"$name\",\"repo_url\": \"$repo_url\",\"branch\": \"$branch\"}]}" >> "$MODULES_CONFIG"
    rm -f "${MODULES_CONFIG}.bak"
  fi
}

# Function to remove a module from the config
remove_module_from_config() {
  local name="$1"
  
  if [ ! -f "$MODULES_CONFIG" ]; then
    return 0  # Nothing to remove
  fi
  
  if command -v jq &> /dev/null; then
    # Remove module from config using jq
    jq --arg name "$name" '.modules = [.modules[] | select(.name != $name)]' \
      "$MODULES_CONFIG" > "${MODULES_CONFIG}.tmp" && mv "${MODULES_CONFIG}.tmp" "$MODULES_CONFIG"
  else
    # This is a simplistic approach that might not work for all cases
    # Proper JSON manipulation without jq is complex
    # Create a temporary file without the module
    grep -v "\"name\": *\"$name\"" "$MODULES_CONFIG" > "${MODULES_CONFIG}.tmp"
    mv "${MODULES_CONFIG}.tmp" "$MODULES_CONFIG"
  fi
}

# Function to add a new SDK to the config
add_sdk_to_config() {
  local name="$1"
  local path="$2"
  local version="${3:-0.1.0}"
  
  # Create config directory if it doesn't exist
  mkdir -p "$CONFIG_DIR"
  
  # Create SDKs config if it doesn't exist
  if [ ! -f "$SDKS_CONFIG" ]; then
    echo '{"sdks": []}' > "$SDKS_CONFIG"
  fi
  
  if command -v jq &> /dev/null; then
    # Add SDK to config using jq
    jq --arg name "$name" \
       --arg path "$path" \
       --arg version "$version" \
       '.sdks += [{"name": $name, "path": $path, "version": $version}]' \
       "$SDKS_CONFIG" > "${SDKS_CONFIG}.tmp" && mv "${SDKS_CONFIG}.tmp" "$SDKS_CONFIG"
  else
    # Manual addition (basic approach)
    # Remove the closing brackets
    sed -i.bak 's/}]}$/},{/g' "$SDKS_CONFIG"
    # Add the new SDK and close the JSON
    echo "\"name\": \"$name\",\"path\": \"$path\",\"version\": \"$version\"}]}" >> "$SDKS_CONFIG"
    rm -f "${SDKS_CONFIG}.bak"
  fi
}

# Function to remove an SDK from the config
remove_sdk_from_config() {
  local name="$1"
  
  if [ ! -f "$SDKS_CONFIG" ]; then
    return 0  # Nothing to remove
  fi
  
  if command -v jq &> /dev/null; then
    # Remove SDK from config using jq
    jq --arg name "$name" '.sdks = [.sdks[] | select(.name != $name)]' \
      "$SDKS_CONFIG" > "${SDKS_CONFIG}.tmp" && mv "${SDKS_CONFIG}.tmp" "$SDKS_CONFIG"
  else
    # This is a simplistic approach that might not work for all cases
    # Proper JSON manipulation without jq is complex
    # Create a temporary file without the SDK
    grep -v "\"name\": *\"$name\"" "$SDKS_CONFIG" > "${SDKS_CONFIG}.tmp"
    mv "${SDKS_CONFIG}.tmp" "$SDKS_CONFIG"
  fi
}

# Function to list all modules with their details
list_modules() {
  if command -v jq &> /dev/null; then
    jq -r '.modules[] | "Module: \(.name)\n  Repository: \(.repo_url)\n  Branch: \(.branch // "main")"' "$MODULES_CONFIG" 2>/dev/null
  else
    echo "Modules:"
    while IFS= read -r module; do
      echo "- $module"
      echo "  Repository: $(get_module_repo_url "$module")"
      echo "  Branch: $(get_module_branch "$module")"
    done < <(get_module_names)
  fi
}

# Function to list all SDKs with their details
list_sdks() {
  if command -v jq &> /dev/null; then
    jq -r '.sdks[] | "SDK: \(.name)\n  Path: \(.path)\n  Version: \(.version)"' "$SDKS_CONFIG" 2>/dev/null
  else
    echo "SDKs:"
    while IFS= read -r sdk; do
      echo "- $sdk"
      echo "  Path: $(get_sdk_path "$sdk")"
      echo "  Version: $(get_sdk_version "$sdk")"
    done < <(get_sdk_names)
  fi
}

# Export functions
export -f get_module_names
export -f get_module_repo_url
export -f get_module_branch
export -f get_sdk_names
export -f get_sdk_path
export -f get_sdk_version
export -f add_module_to_config
export -f remove_module_from_config
export -f add_sdk_to_config
export -f remove_sdk_from_config
export -f list_modules
export -f list_sdks