#!/usr/bin/env bash
# =============================================================================
# 校验 make defconfig 之后 .config 里是否只启用了目标设备
#
# 用法：
#   ./scripts/verify-config.sh an7581 nokia_xg-040g-md-ubi ./ponwrt/.config
# =============================================================================
set -euo pipefail

SOC="${1:-}"
PROFILE="${2:-}"
CONFIG_FILE="${3:-ponwrt/.config}"

if [ -z "$SOC" ] || [ -z "$PROFILE" ]; then
  echo "用法: $0 <soc> <profile> [config]" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "错误：找不到配置文件 $CONFIG_FILE" >&2
  exit 1
fi

fail=0

check_yes() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$CONFIG_FILE"; then
    echo "OK   $label"
  else
    echo "MISS $label"
    fail=1
  fi
}

check_no() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$CONFIG_FILE"; then
    echo "FAIL $label（不应启用）"
    fail=1
  else
    echo "OK   $label 未启用"
  fi
}

echo "--- 目标平台 ---"
check_yes '^CONFIG_TARGET_BOARD="airoha"$' 'CONFIG_TARGET_BOARD="airoha"'
check_yes "^CONFIG_TARGET_SUBTARGET=\"${SOC}\"$" "CONFIG_TARGET_SUBTARGET=\"${SOC}\""

echo "--- 设备选择 ---"
check_yes "^CONFIG_TARGET_DEVICE_airoha_${SOC}_DEVICE_${PROFILE}=y$" "目标设备 ${PROFILE}"
check_yes '^CONFIG_TARGET_MULTI_PROFILE=y$' 'CONFIG_TARGET_MULTI_PROFILE'
check_yes '^CONFIG_TARGET_PER_DEVICE_ROOTFS=y$' 'CONFIG_TARGET_PER_DEVICE_ROOTFS'
check_no '^CONFIG_TARGET_ALL_PROFILES=y$' 'CONFIG_TARGET_ALL_PROFILES'

mapfile -t selected < <(
  grep -E '^CONFIG_TARGET_DEVICE_airoha_[A-Za-z0-9_]+_DEVICE_.*=y$' "$CONFIG_FILE" || true
)
if [ "${#selected[@]}" -ne 1 ]; then
  echo "FAIL 期望只启用 1 个设备，实际启用 ${#selected[@]} 个："
  printf '     %s\n' "${selected[@]}"
  fail=1
elif [ "${selected[0]}" != "CONFIG_TARGET_DEVICE_airoha_${SOC}_DEVICE_${PROFILE}=y" ]; then
  echo "FAIL 启用的设备不是目标设备：${selected[0]}"
  fail=1
else
  echo "OK   只启用了目标设备"
fi

echo "--- 基础功能 ---"
check_yes '^CONFIG_PACKAGE_luci=y$' 'LuCI'
check_yes '^CONFIG_TARGET_ROOTFS_SQUASHFS=y$' 'SquashFS rootfs'

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "!! .config 校验失败，当前所有已选设备："
  grep -E '^CONFIG_TARGET_DEVICE_.*=y$' "$CONFIG_FILE" || true
  exit 1
fi

echo ""
echo "配置校验通过：airoha/${SOC} / ${PROFILE}"
