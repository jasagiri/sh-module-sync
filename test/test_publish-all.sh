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
  cp "$ORIGINAL_DIR/../scripts/publish-all.sh" scripts/ || cp "$ORIGINAL_DIR/scripts/publish-all.sh" scripts/
  
  # SDK(nǣ���\
  for sdk in "sync-sdk" "ai-sdk" "storage-sdk" "security-sdk" "net-sdk" "ui-sdk" "obs-sdk" "devops-sdk" "api-gateway-sdk" "config-sdk" "cli-sdk" "docs-sdk" "test-sdk" "compliance-sdk"; do
    mkdir -p "$sdk"
  done
  
  # nimble����n�ï
  cat > nimble << 'EOF'
#!/bin/bash
if [[ "$1" == "publish" ]]; then
  echo "Publishing package..."
  CURRENT_DIR=$(basename $(pwd))
  echo "${CURRENT_DIR}" >> "$TEST_DIR/published_sdks.txt"
  exit 0
else
  echo "Unknown nimble command: $*"
  exit 1
fi
EOF
  chmod +x nimble
  export PATH="$TEST_DIR:$PATH"
}

# nimble1W���n�ï�\
setup_failing_env() {
  cd "$TEST_DIR" || exit 1
  
  # SDKǣ���\
  mkdir -p "sync-sdk" "ai-sdk" "failing-sdk"
  
  # ����Ȓ��Wfƹ�(nSDK�Ȓ(
  cat > scripts/publish-all.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# l��aSDK �
SDKS=(
  "sync-sdk"
  "ai-sdk"
  "failing-sdk"
)

# SDK�l�
for sdk in "${SDKS[@]}"; do
  echo "Publishing ${sdk}..."
  pushd "${sdk}" > /dev/null
  nimble publish || {
    echo "[ERROR] Failed to publish ${sdk}"
    exit 1
  }
  popd > /dev/null
  echo " ${sdk} published"
done

echo "<� All SDKs published successfully"
EOF
  
  # nimble����n1WY��ïy�nSDKg1W	
  cat > nimble << 'EOF'
#!/bin/bash
if [[ "$1" == "publish" ]]; then
  CURRENT_DIR=$(basename $(pwd))
  if [[ "$CURRENT_DIR" == "failing-sdk" ]]; then
    echo "Error: Failed to publish package" >&2
    exit 1
  fi
  echo "Publishing package..."
  echo "${CURRENT_DIR}" >> "$TEST_DIR/published_sdks.txt"
  exit 0
else
  echo "Unknown nimble command: $*"
  exit 1
fi
EOF
  chmod +x nimble
  export PATH="$TEST_DIR:$PATH"
}

# SDK �n<
test_sdk_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # ����Ȓ�L
  ./scripts/publish-all.sh
  
  # P��<
  if [ ! -f "published_sdks.txt" ]; then
    echo "FAIL: No SDKs were published"
    exit 1
  fi
  
  # YyfnSDKLl�U�_Sh���
  EXPECTED_SDKS=(
    "sync-sdk"
    "ai-sdk" 
    "storage-sdk"
    "security-sdk"
    "net-sdk"
    "ui-sdk"
    "obs-sdk"
    "devops-sdk"
    "api-gateway-sdk"
    "config-sdk"
    "cli-sdk"
    "docs-sdk"
    "test-sdk"
    "compliance-sdk"
  )
  
  for sdk in "${EXPECTED_SDKS[@]}"; do
    if ! grep -q "^${sdk}$" published_sdks.txt; then
      echo "FAIL: SDK ${sdk} was not published"
      exit 1
    fi
  done
  
  # YjSDKLjDSh���
  if [ "$(wc -l < published_sdks.txt)" -ne "${#EXPECTED_SDKS[@]}" ]; then
    echo "FAIL: Unexpected SDKs were published"
    cat published_sdks.txt
    exit 1
  fi
  
  echo "PASS: All SDKs were correctly published"
}

# l�1W���
test_publish_failure() {
  setup_failing_env
  cd "$TEST_DIR" || exit 1
  
  # ����Ȓ�L1WY�oZ	
  if ./scripts/publish-all.sh 2>/dev/null; then
    echo "FAIL: Script should have failed but succeeded"
    exit 1
  fi
  
  # 1WY�~gnSDKLl�U�_Sh���
  if ! grep -q "^sync-sdk$" published_sdks.txt 2>/dev/null; then
    echo "FAIL: sync-sdk should have been published before failure"
    exit 1
  fi
  
  if ! grep -q "^ai-sdk$" published_sdks.txt 2>/dev/null; then
    echo "FAIL: ai-sdk should have been published before failure"
    exit 1
  fi
  
  if grep -q "^failing-sdk$" published_sdks.txt 2>/dev/null; then
    echo "FAIL: failing-sdk should not have been published"
    exit 1
  fi
  
  echo "PASS: Script correctly failed when SDK publish failed"
}

# �������ƹ�
test_script_output() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # �����n���֗
  output=$(./scripts/publish-all.sh)
  
  # SDKkdDfn�����
  for sdk in "sync-sdk" "ai-sdk" "storage-sdk"; do
    if ! echo "$output" | grep -q "Publishing ${sdk}"; then
      echo "FAIL: Output missing publish message for ${sdk}"
      exit 1
    fi
    
    if ! echo "$output" | grep -q " ${sdk} published"; then
      echo "FAIL: Output missing success message for ${sdk}"
      exit 1
    fi
  done
  
  # ��û�����
  if ! echo "$output" | grep -q "<� All SDKs published successfully"; then
    echo "FAIL: Final success message not found in output"
    exit 1
  fi
  
  echo "PASS: Script output is correct"
}

# ����SDK �ƹ�SDKSL	�U�_4	
test_custom_sdk_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # ��n����SDK�\
  mkdir -p "custom-sdk1" "custom-sdk2"
  
  # publish-all.sh���WfSDK �����ޤ�
  cat > scripts/publish-all.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# l��aSDK �
SDKS=(
  "custom-sdk1"
  "custom-sdk2"
)

# SDK�l�
for sdk in "${SDKS[@]}"; do
  echo "Publishing ${sdk}..."
  pushd "${sdk}" > /dev/null
  nimble publish || {
    echo "[ERROR] Failed to publish ${sdk}"
    exit 1
  }
  popd > /dev/null
  echo " ${sdk} published"
done

echo "<� All SDKs published successfully"
EOF
  
  # ����Ȓ�L
  ./scripts/publish-all.sh
  
  # P��<
  EXPECTED_SDKS=("custom-sdk1" "custom-sdk2")
  for sdk in "${EXPECTED_SDKS[@]}"; do
    if ! grep -q "^${sdk}$" published_sdks.txt; then
      echo "FAIL: SDK ${sdk} was not published"
      exit 1
    fi
  done
  
  echo "PASS: Custom SDK list test passed"
}

# SDK �Lzn4nƹ�
test_empty_sdk_list() {
  setup_test_env
  cd "$TEST_DIR" || exit 1
  
  # publish-all.sh���WfSDK ��zkY�
  cat > scripts/publish-all.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# l��aSDK �
SDKS=()

# SDK�l�
for sdk in "${SDKS[@]}"; do
  echo "Publishing ${sdk}..."
  pushd "${sdk}" > /dev/null
  nimble publish || {
    echo "[ERROR] Failed to publish ${sdk}"
    exit 1
  }
  popd > /dev/null
  echo " ${sdk} published"
done

echo "<� All SDKs published successfully"
EOF
  
  # ����Ȓ�L
  output=$(./scripts/publish-all.sh)
  
  # P��<
  if [ -f "published_sdks.txt" ]; then
    echo "FAIL: SDKs were published but should not have been"
    exit 1
  fi
  
  # ��û�����
  if ! echo "$output" | grep -q "<� All SDKs published successfully"; then
    echo "FAIL: Success message not found in output"
    exit 1
  fi
  
  echo "PASS: Empty SDK list test passed"
}

# ��L
test_sdk_list
test_publish_failure
test_script_output
test_custom_sdk_list
test_empty_sdk_list

echo " All tests passed"

# Cnǣ���k;�
cd "$ORIGINAL_DIR"