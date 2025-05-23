#!/usr/bin/env bash
set -euo pipefail

# Load helper functions
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test_helper.sh"

# Current directory
ORIGINAL_DIR=$(pwd)

# ƹ�(n Bǣ���\
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# ƹ�(nGit�ݸ��
setup_test_repo() {
  cd "$TEST_DIR" || exit 1
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"
  touch README.md
  git add README.md
  git commit -m "Initial commit"
  
  # ƹ�(n�����ݸ��\
  mkdir -p module_remote
  cd module_remote
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"
  touch README.md
  git add README.md
  git commit -m "Initial module commit"
  cd ..
  
  # jj����n��������
  mkdir -p .jj
  touch .jj-workspace
  
  # jj����n�ï
  cat > jj << 'EOF'
#!/bin/bash
if [[ "$1" == "clone" ]]; then
  mkdir -p "$3"
  touch "$3/jj-cloned"
  exit 0
elif [[ "$1" == "workspace" && "$2" == "commit" ]]; then
  echo "$4" > .jj/last_commit_message
  exit 0
else
  echo "Unexpected jj command: $*"
  exit 1
fi
EOF
  chmod +x jj
  export PATH="$TEST_DIR:$PATH"
}

# ��ð(�p
debug() {
  echo "DEBUG: $1"
  git remote -v
  ls -la
  if [ -f .jj-workspace ]; then
    cat .jj-workspace
  fi
}

# p�ƹ�
test_missing_arguments() {
  cd "$TEST_DIR" || exit 1
  
  # pjW
  local output
  output=$("$ORIGINAL_DIR/../scripts/add_module.sh" 2>&1 || true)
  if [[ "$output" != *"Usage:"* ]]; then
    echo "FAIL: Missing argument test (no args) failed"
    exit 1
  fi
  
  # p d
  output=$("$ORIGINAL_DIR/../scripts/add_module.sh" "https://example.com/repo.git" 2>&1 || true)
  if [[ "$output" != *"Usage:"* ]]; then
    echo "FAIL: Missing argument test (one arg) failed"
    exit 1
  fi
  
  echo "PASS: Missing arguments test"
}

# ������1Wƹ�
test_remote_add_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # ������1Wn��������
  chmod -w .git/config
  
  local output
  output=$("$ORIGINAL_DIR/../scripts/add_module.sh" "https://example.com/nonexistent.git" "test_module" 2>&1 || true)
  
  # )P�;Y
  chmod +w .git/config
  
  if [[ "$output" != *"[ERROR] Failed to add remote"* ]]; then
    echo "FAIL: Remote add failure test failed"
    exit 1
  fi
  
  echo "PASS: Remote add failure test"
}

# �������1Wƹ�
test_subtree_add_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # git subtree����n�ï1WY������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "remote" && "$2" == "add" ]]; then
  # ��k���Ȓ��
  $(which git) remote add "$3" "$4"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "add" ]]; then
  # �������n1W�������
  echo "fatal: Failed to add subtree"
  exit 1
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  export PATH="$TEST_DIR:$PATH"
  
  local output
  output=$(../scripts/add_module.sh "https://example.com/test_repo.git" "test_module" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to add subtree"* ]]; then
    echo "FAIL: Subtree add failure test failed"
    echo "Output was: $output"
    exit 1
  fi
  
  echo "PASS: Subtree add failure test"
}

# jj����1Wƹ�
test_jj_clone_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # jj����n�ï����L1WY������	
  cat > jj << 'EOF'
#!/bin/bash
if [[ "$1" == "clone" ]]; then
  echo "Error: Failed to clone repository"
  exit 1
elif [[ "$1" == "workspace" && "$2" == "commit" ]]; then
  echo "$4" > .jj/last_commit_message
  exit 0
else
  echo "Unexpected jj command: $*"
  exit 1
fi
EOF
  chmod +x jj
  
  # gitn�ï�������L�Y������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "remote" && "$2" == "add" ]]; then
  # ��k���Ȓ��
  $(which git) remote add "$3" "$4"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "add" ]]; then
  # �������n��������
  mkdir -p "subtrees/test_module"
  touch "subtrees/test_module/subtree-added"
  exit 0
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  export PATH="$TEST_DIR:$PATH"
  
  local output
  output=$(../scripts/add_module.sh "https://example.com/test_repo.git" "test_module" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to clone with jj"* ]]; then
    echo "FAIL: JJ clone failure test failed"
    echo "Output was: $output"
    exit 1
  fi
  
  echo "PASS: JJ clone failure test"
}

# c8�ƹ�
test_successful_add() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # gitn�ïYyfL�Y������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "remote" && "$2" == "add" ]]; then
  # ��k���Ȓ��
  $(which git) remote add "$3" "$4"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "add" ]]; then
  # �������n��������
  mkdir -p "subtrees/test_module"
  touch "subtrees/test_module/subtree-added"
  exit 0
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  
  # jj����n�ïYyf�Y������	
  cat > jj << 'EOF'
#!/bin/bash
if [[ "$1" == "clone" ]]; then
  mkdir -p "$3"
  touch "$3/jj-cloned"
  exit 0
elif [[ "$1" == "workspace" && "$2" == "commit" ]]; then
  echo "$4" > .jj/last_commit_message
  exit 0
else
  echo "Unexpected jj command: $*"
  exit 1
fi
EOF
  chmod +x jj
  export PATH="$TEST_DIR:$PATH"
  
  # ƹȟL
  local output
  output=$(../scripts/add_module.sh "https://example.com/test_repo.git" "test_module" 2>&1)
  
  # <
  if ! git remote -v | grep -q "test_module-remote"; then
    echo "FAIL: Remote was not added"
    exit 1
  fi
  
  if [ ! -d "subtrees/test_module" ]; then
    echo "FAIL: Subtree directory was not created"
    exit 1
  fi
  
  if [ ! -f "subtrees/test_module/subtree-added" ]; then
    echo "FAIL: Subtree was not properly added"
    exit 1
  fi
  
  if [ ! -f ".jj/last_commit_message" ] || ! grep -q "add test_module" ".jj/last_commit_message"; then
    echo "FAIL: Workspace was not updated"
    exit 1
  fi
  
  if ! grep -q "subtrees/test_module" .jj-workspace; then
    echo "FAIL: Module not added to .jj-workspace"
    exit 1
  fi
  
  if [[ "$output" != *"Successfully added module test_module"* ]]; then
    echo "FAIL: Success message not displayed"
    exit 1
  fi
  
  echo "PASS: Successful add test"
}

# ��L
test_missing_arguments
test_remote_add_failure
test_subtree_add_failure
test_jj_clone_failure
test_successful_add

echo " All tests passed"

# Cnǣ���k;�
cd "$ORIGINAL_DIR"