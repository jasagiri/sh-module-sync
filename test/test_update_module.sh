#!/usr/bin/env bash
set -euo pipefail

# Cnǣ����X
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
  
  # ƹ�(����\
  mkdir -p subtrees/test_module
  touch subtrees/test_module/test_file.txt
  git add subtrees/test_module
  git commit -m "Add test module"
  git remote add test_module-remote "https://example.com/test_module.git"
  
  # jj����n��������
  mkdir -p .jj
  touch .jj/last_commit_message
  
  # jj����n�ï
  cat > jj << 'EOF'
#!/bin/bash
if [[ "$1" == "pull" ]]; then
  echo "Pulled latest changes"
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
  ls -la subtrees/
  if [ -f .jj/last_commit_message ]; then
    cat .jj/last_commit_message
  fi
}

# p�ƹ�
test_missing_argument() {
  cd "$TEST_DIR" || exit 1
  
  local output
  output=$("$ORIGINAL_DIR/../scripts/update_module.sh" 2>&1 || true)
  if [[ "$output" != *"Usage:"* ]]; then
    echo "FAIL: Missing argument test failed"
    exit 1
  fi
  echo "PASS: Missing argument test"
}

# git fetch1Wƹ�
test_fetch_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # gitn�ïfetchL1WY������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "fetch" ]]; then
  echo "fatal: Could not fetch from remote"
  exit 1
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  export PATH="$TEST_DIR:$PATH"
  
  local output
  output=$(../scripts/update_module.sh "test_module" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to fetch from remote"* ]]; then
    echo "FAIL: Fetch failure test failed"
    echo "Output was: $output"
    exit 1
  fi
  
  echo "PASS: Fetch failure test"
}

# git subtree pull1Wƹ�
test_subtree_pull_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # gitn�ïfetcho�subtree pullL1WY������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "fetch" ]]; then
  echo "From https://example.com/test_module.git"
  echo " * branch            main       -> FETCH_HEAD"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "pull" ]]; then
  echo "fatal: Failed to merge remote changes"
  exit 1
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  export PATH="$TEST_DIR:$PATH"
  
  local output
  output=$(../scripts/update_module.sh "test_module" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to update subtree"* ]]; then
    echo "FAIL: Subtree pull failure test failed"
    echo "Output was: $output"
    exit 1
  fi
  
  echo "PASS: Subtree pull failure test"
}

# jj pull1Wƹ�
test_jj_pull_failure() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # gitn�ïfetchhsubtree pullL�Y������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "fetch" ]]; then
  echo "From https://example.com/test_module.git"
  echo " * branch            main       -> FETCH_HEAD"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "pull" ]]; then
  echo "Successfully pulled changes"
  exit 0
else
  # ]��n����o��ngitk!Y
  $(which git) "$@"
fi
EOF
  chmod +x git
  
  # jj����n�ïpullL1WY������	
  cat > jj << 'EOF'
#!/bin/bash
if [[ "$1" == "pull" ]]; then
  echo "Error: Failed to pull changes"
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
  export PATH="$TEST_DIR:$PATH"
  
  local output
  output=$(../scripts/update_module.sh "test_module" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to pull with jj"* ]]; then
    echo "FAIL: JJ pull failure test failed"
    echo "Output was: $output"
    exit 1
  fi
  
  echo "PASS: JJ pull failure test"
}

# c8�ƹ�
test_successful_update() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  # gitn�ïYyfL�Y������	
  cat > git << 'EOF'
#!/bin/bash
if [[ "$1" == "fetch" ]]; then
  echo "From https://example.com/test_module.git"
  echo " * branch            main       -> FETCH_HEAD"
  exit 0
elif [[ "$1" == "subtree" && "$2" == "pull" ]]; then
  echo "Successfully pulled changes"
  # ���������
  echo "updated content" > subtrees/test_module/test_file.txt
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
if [[ "$1" == "pull" ]]; then
  echo "Pulled latest changes"
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
  output=$(../scripts/update_module.sh "test_module" 2>&1)
  
  # <
  if [ ! -f "subtrees/test_module/test_file.txt" ]; then
    echo "FAIL: Module directory structure not maintained"
    exit 1
  fi
  
  if ! grep -q "updated content" "subtrees/test_module/test_file.txt"; then
    echo "FAIL: Module content was not updated"
    exit 1
  fi
  
  if [ ! -f ".jj/last_commit_message" ] || ! grep -q "update test_module workspace" ".jj/last_commit_message"; then
    echo "FAIL: Workspace was not updated"
    exit 1
  fi
  
  if [[ "$output" != *"Successfully updated module test_module"* ]]; then
    echo "FAIL: Success message not displayed"
    exit 1
  fi
  
  echo "PASS: Successful update test"
}

# X(WjD����ƹ�
test_nonexistent_module() {
  setup_test_repo
  cd "$TEST_DIR" || exit 1
  
  local output
  output=$(../scripts/update_module.sh "nonexistent" 2>&1 || true)
  
  if [[ "$output" != *"[ERROR] Failed to fetch from remote nonexistent-remote"* ]]; then
    echo "FAIL: Nonexistent module test failed"
    exit 1
  fi
  
  echo "PASS: Nonexistent module test"
}

# ��L
test_missing_argument
test_fetch_failure
test_subtree_pull_failure
test_jj_pull_failure
test_successful_update
test_nonexistent_module

echo " All tests passed"

# Cnǣ���k;�
cd "$ORIGINAL_DIR"