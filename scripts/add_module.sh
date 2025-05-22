#!/usr/bin/env bash
set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration utilities
source "${SCRIPT_DIR}/lib/config.sh"

# 引数チェック
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
  echo "Usage: $0 <git_repo_url> <module_name> [branch]"
  exit 1
fi

REPO_URL=$1
MODULE=$2
BRANCH=${3:-main}
REMOTE="${MODULE}-remote"
PREFIX="subtrees/${MODULE}"

# Gitリモート追加
git remote add "${REMOTE}" "${REPO_URL}" || {
  echo "[ERROR] Failed to add remote ${REMOTE}"
  exit 1
}

# Gitサブツリー追加
git subtree add --prefix="${PREFIX}" "${REMOTE}" "${BRANCH}" --squash || {
  echo "[ERROR] Failed to add subtree for ${MODULE}"
  exit 1
}

# Jujutsu Workspace設定
jj clone "${REPO_URL}" "${PREFIX}" || {
  echo "[ERROR] Failed to clone with jj"
  exit 1
}

echo "${PREFIX}" >> .jj-workspace
jj workspace commit -m "chore: add ${MODULE} to workspace"

# Add module to configuration file
add_module_to_config "${MODULE}" "${REPO_URL}" "${BRANCH}"

echo "✅ Successfully added module ${MODULE}"