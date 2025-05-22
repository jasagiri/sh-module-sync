#!/usr/bin/env bash
set -euo pipefail

# 元のディレクトリを保存
ORIGINAL_DIR=$(pwd)

# テスト用の一時ディレクトリ作成
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# テスト用のGitリポジトリ初期化
setup_test_repo() {
  cd "$TEST_DIR" || exit 1
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"
  touch README.md
  git add README.md
  git commit -m "Initial commit"
  
  # テスト用モジュール作成
  mkdir -p subtrees/test_module
  git add subtrees/test_module
  git commit -m "Add test module"
  git remote add test_module-remote "https://example.com/test_module.git"
  
  # jjコマンドのエミュレーション
  mkdir -p .jj
  echo "chore: Add test module" > .jj/last_commit_message
}

# デバッグ用関数
debug() {
  echo "DEBUG: $1"
  git remote -v
  ls -la subtrees/
}

# 引数不足テスト
test_missing_argument() {
  local output
  output=$("$ORIGINAL_DIR/../scripts/remove_module.sh" 2>&1 || true)
  if [[ "$output" != *"Usage:"* ]]; then
    echo "FAIL: Missing argument test failed"
    exit 1
  fi
  echo "PASS: Missing argument test"
}

# 正常系テスト
test_successful_removal() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  echo "=== テスト環境設定完了 ==="
  echo "カレントディレクトリ: $(pwd)"
  echo "ディレクトリ内容:"
  ls -la
  echo "Gitリモート一覧:"
  git remote -v
  echo "Gitサブツリー状態:"
  git log --oneline --graph --all
  
  # テスト対象スクリプト実行
  echo "=== スクリプト実行開始 ==="
  echo "スクリプトの内容:"
  cat ../scripts/remove_module.sh
  echo "現在の環境変数:"
  env
  echo "ファイルシステム状態:"
  find . -type f -exec ls -la {} \;
  
  if ! ../scripts/remove_module.sh test_module; then
    echo "FAIL: スクリプト実行エラー"
    echo "=== エラー発生時の状態 ==="
    echo "カレントディレクトリ: $(pwd)"
    echo "ディレクトリ内容:"
    ls -la
    echo "Gitリモート一覧:"
    git remote -v
    echo "Gitサブツリー状態:"
    git log --oneline --graph --all
    exit 1
  fi
  
  echo "=== スクリプト実行完了 ==="
  echo "最終状態確認:"
  echo "カレントディレクトir: $(pwd)"
  echo "ディレクトリ内容:"
  ls -la
  echo "Gitリモート一覧:"
  git remote -v
  echo "Gitサブツリー状態:"
  git log --oneline --graph --all
  
  # 検証
  if git remote | grep -q "test_module-remote"; then
    echo "FAIL: リモートが削除されていません"
    exit 1
  fi
  
  if [ -d "subtrees/test_module" ]; then
    echo "FAIL: サブツリーディレクトリが残っています"
    exit 1
  fi
  
  if [ ! -f ".jj/last_commit_message" ] || ! grep -q "remove test_module" ".jj/last_commit_message"; then
    echo "FAIL: Workspaceが更新されていません"
    exit 1
  fi
  
  echo "PASS: 正常系テスト成功"
  
  # 検証
  if git remote | grep -q "test_module-remote"; then
    echo "FAIL: Remote was not removed"
    exit 1
  fi
  
  if [ -d "subtrees/test_module" ]; then
    echo "FAIL: Subtree directory still exists"
    exit 1
  fi
  
  if [ ! -f ".jj/last_commit_message" ] || ! grep -q "remove test_module" ".jj/last_commit_message"; then
    echo "FAIL: Workspace was not updated"
    exit 1
  fi
  
  echo "PASS: Successful removal test"
}

# 存在しないモジュールテスト
test_nonexistent_module() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  local output
  output=$(../scripts/remove_module.sh nonexistent 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to remove remote nonexistent-remote"* ]]; then
    echo "FAIL: Nonexistent module test failed"
    exit 1
  fi
  
  echo "PASS: Nonexistent module test"
}

# Gitリモート削除失敗テスト
test_remote_removal_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # リモート削除を失敗させる
  chmod -w .git/config
  
  local output
  output=$(../scripts/remove_module.sh test_module 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to remove remote test_module-remote"* ]]; then
    echo "FAIL: Remote removal failure test failed"
    exit 1
  fi
  
  chmod +w .git/config
  echo "PASS: Remote removal failure test"
}

# メイン実行
test_missing_argument
test_successful_removal
test_nonexistent_module
test_remote_removal_failure

echo "✅ All tests passed"

# 元のディレクトリに戻る
cd "$ORIGINAL_DIR"