#!/usr/bin/env bash
set -euo pipefail

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration utilities
source "${SCRIPT_DIR}/lib/config.sh"

# 引数チェック
if [ $# -ne 1 ]; then
  echo "Usage: $0 <module_name>"
  exit 1
fi

MODULE=$1
REMOTE="${MODULE}-remote"
PREFIX="subtrees/${MODULE}"

# Gitリモート削除
git remote remove "${REMOTE}" || {
  echo "[ERROR] Failed to remove remote ${REMOTE}"
  exit 1
}

# Gitサブツリー削除
git rm -r "${PREFIX}" || {
  echo "[ERROR] Failed to remove subtree for ${MODULE}"
  exit 1
}

# Jujutsuリポジトリ削除
rm -rf "${PREFIX}" || {
  echo "[ERROR] Failed to remove jujutsu repository for ${MODULE}"
  exit 1
}

# Workspace更新
jj workspace commit -m "chore: remove ${MODULE} from workspace"

# Remove module from configuration file
remove_module_from_config "${MODULE}"

echo "✅ Successfully removed module ${MODULE}"