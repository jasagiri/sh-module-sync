#!/usr/bin/env bash
set -euo pipefail

# Cnǣ����X
ORIGINAL_DIR=$(pwd)

# ƹ�(n Bǣ���\
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# ƹ�(n����Ȣ��
setup_test_env() {
  cd "$TEST_DIR" || exit 1
  
  # ����Ȓ���
  mkdir -p scripts
  cp "$ORIGINAL_DIR/../scripts/sync-all.sh" scripts/ || cp "$ORIGINAL_DIR/scripts/sync-all.sh" scripts/
  
  # update_module.shn�ï�\
  cat > update_module.sh << 'EOF'
#!/bin/bash
MODULE=$1
echo "Mock: Updating module ${MODULE}"
echo "${MODULE}" >> updated_modules.txt
exit 0
EOF
  chmod +x update_module.sh
}

# update_module.sh1W���n�ï�\
setup_failing_env() {
  cd "$TEST_DIR" || exit 1
  
  # update_module.shn1WY��ï�\
  cat > update_module.sh << 'EOF'
#!/bin/bash
MODULE=$1
echo "Mock: Failed to update module ${MODULE}" >&2
exit 1
EOF
  chmod +x update_module.sh
}

# ���� �n<
test_module_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # ����Ȓ�L
  ./scripts/sync-all.sh
  
  # P��<
  if [ ! -f "updated_modules.txt" ]; then
    echo "FAIL: No modules were updated"
    exit 1
  fi
  
  # Yyfn����L��U�_Sh���
  EXPECTED_MODULES=("module1" "module2" "module3" "module4")
  for module in "${EXPECTED_MODULES[@]}"; do
    if ! grep -q "^${module}$" updated_modules.txt; then
      echo "FAIL: Module ${module} was not updated"
      exit 1
    fi
  done
  
  # Yj����LjDSh���
  if [ "$(wc -l < updated_modules.txt)" -ne "${#EXPECTED_MODULES[@]}" ]; then
    echo "FAIL: Unexpected modules were updated"
    cat updated_modules.txt
    exit 1
  fi
  
  echo "PASS: All modules were correctly updated"
}

# ��1W���
test_update_failure() {
  setup_failing_env
  cd "$TEST_DIR" || exit 1
  
  # ����Ȓ�L1WY�oZ	
  if ./scripts/sync-all.sh 2>/dev/null; then
    echo "FAIL: Script should have failed but succeeded"
    exit 1
  fi
  
  echo "PASS: Script correctly failed when module update failed"
}

# �������ƹ�
test_script_output() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # �����n���֗
  output=$(./scripts/sync-all.sh)
  
  # ����kdDfn�����
  for module in "module1" "module2" "module3" "module4"; do
    if ! echo "$output" | grep -q "Syncing ${module}"; then
      echo "FAIL: Output missing sync message for ${module}"
      exit 1
    fi
  done
  
  # ��û�����
  if ! echo "$output" | grep -q "All modules synced successfully"; then
    echo "FAIL: Success message not found in output"
    exit 1
  fi
  
  echo "PASS: Script output is correct"
}

# �������� �ƹ�MODULESL	�U�_4	
test_custom_module_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # sync-all.sh���Wf���� �����ޤ�
  cat > scripts/sync-all.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ���� �
MODULES=(
  "custom1"
  "custom2"
)

# ����
for module in "${MODULES[@]}"; do
  echo "Syncing ${module}..."
  ./update_module.sh "${module}"
done

echo " All modules synced successfully"
EOF
  
  # ����Ȓ�L
  ./scripts/sync-all.sh
  
  # P��<
  EXPECTED_MODULES=("custom1" "custom2")
  for module in "${EXPECTED_MODULES[@]}"; do
    if ! grep -q "^${module}$" updated_modules.txt; then
      echo "FAIL: Module ${module} was not updated"
      exit 1
    fi
  done
  
  # Yj����LjDSh���
  if [ "$(wc -l < updated_modules.txt)" -ne "${#EXPECTED_MODULES[@]}" ]; then
    echo "FAIL: Unexpected modules were updated"
    cat updated_modules.txt
    exit 1
  fi
  
  echo "PASS: Custom module list test passed"
}

# ���� �Lzn4nƹ�
test_empty_module_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # sync-all.sh���Wf���� ��zkY�
  cat > scripts/sync-all.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ���� �
MODULES=()

# ����
for module in "${MODULES[@]}"; do
  echo "Syncing ${module}..."
  ./update_module.sh "${module}"
done

echo " All modules synced successfully"
EOF
  
  # ����Ȓ�L
  output=$(./scripts/sync-all.sh)
  
  # P��<
  if [ -f "updated_modules.txt" ]; then
    echo "FAIL: Modules were updated but should not have been"
    exit 1
  fi
  
  # ��û�����
  if ! echo "$output" | grep -q "All modules synced successfully"; then
    echo "FAIL: Success message not found in output"
    exit 1
  fi
  
  echo "PASS: Empty module list test passed"
}

# ��L
test_module_list
test_update_failure
test_script_output
test_custom_module_list
test_empty_module_list

echo " All tests passed"

# Cnǣ���k;�
cd "$ORIGINAL_DIR"