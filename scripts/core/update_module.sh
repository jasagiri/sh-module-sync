#!/usr/bin/env bash
set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "${SCRIPT_DIR}")"

# Load configuration utilities
source "${PARENT_DIR}/lib/config.sh"

# 引数チェック
if [ $# -ne 1 ]; then
  echo "Usage: $0 <module_name>"
  exit 1
fi

MODULE=$1
REMOTE="${MODULE}-remote"
PREFIX="subtrees/${MODULE}"

# Get branch from config or default to main
BRANCH=$(get_module_branch "${MODULE}")
if [ -z "$BRANCH" ]; then
  BRANCH="main"
fi

# Gitリモートから最新を取得
git fetch "${REMOTE}" "${BRANCH}" || {
  echo "[ERROR] Failed to fetch from remote ${REMOTE}"
  exit 1
}

# Gitサブツリー更新
git subtree pull --prefix="${PREFIX}" "${REMOTE}" "${BRANCH}" --squash || {
  echo "[ERROR] Failed to update subtree for ${MODULE}"
  exit 1
}

# Jujutsuリポジトリ更新
pushd "${PREFIX}" > /dev/null
jj pull || {
  echo "[ERROR] Failed to pull with jj"
  exit 1
}
popd > /dev/null

# Workspace更新
jj workspace commit -m "chore: update ${MODULE} workspace"

echo "✅ Successfully updated module ${MODULE}"