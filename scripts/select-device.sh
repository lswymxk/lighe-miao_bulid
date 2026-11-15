#!/usr/bin/env bash
# =============================================================================
# 根据设备型号生成只包含该设备的 PonWrt .config
#
# 用法：
#   ./scripts/select-device.sh "XG-040G-MD" ./ponwrt
#
# 做的事情：
#   1. 设备型号 -> SoC（an7581 / an7583）与 profile 映射
#   2. 合并 PonWrt 官方 configs/<soc>.config 与 configs/release.config
#   3. 删除配置里所有已选设备，只追加目标设备
#   4. 输出 soc / profile 到 $GITHUB_OUTPUT，供后续步骤使用
# =============================================================================
set -euo pipefail

DEVICE="${1:-}"
PONWRT_DIR="${2:-ponwrt}"

if [ -z "$DEVICE" ]; then
  echo "用法: $0 <设备型号> [ponwrt目录]" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 设备型号 -> SoC / profile
# 新增设备时，同时更新 workflow 的 device.options 和 README 的表格。
# -----------------------------------------------------------------------------
case "$DEVICE" in
  # ---------------------------- AN7581 --------------------------------------
  "XG-040G-MD")   SOC="an7581"; PROFILE="nokia_xg-040g-md-ubi" ;;
  "XG-040G-TF")   SOC="an7581"; PROFILE="nokia_xg-040g-tf-ubi" ;;
  "HG5382A")      SOC="an7581"; PROFILE="fiberhome_hg5382a" ;;
  "HG5585F-CT")   SOC="an7581"; PROFILE="fiberhome_hg5585f-ct" ;;
  "HG5585F-CU")   SOC="an7581"; PROFILE="fiberhome_hg5585f-cu" ;;
  "XG2010G")      SOC="an7581"; PROFILE="gemtek_xg2010g" ;;
  "UNG00A")       SOC="an7581"; PROFILE="unionman_ung00a" ;;
  "ZN504XG-D")    SOC="an7581"; PROFILE="znxt_zn504xg-d" ;;
  "ZN515XG-D")    SOC="an7581"; PROFILE="znxt_zn515xg-d" ;;
  "HM2004-DU")    SOC="an7581"; PROFILE="h3c_hm2004-du" ;;
  # ---------------------------- AN7583 --------------------------------------
  "XG-040G-MF")     SOC="an7583"; PROFILE="nokia_xg-040g-mf" ;;
  "XG-040G-MF-UBI") SOC="an7583"; PROFILE="nokia_xg-040g-mf-ubi" ;;
  *)
    echo "错误：不支持的设备型号: $DEVICE" >&2
    echo "可选型号：XG-040G-MD, XG-040G-TF, HG5382A, HG5585F-CT, HG5585F-CU," >&2
    echo "          XG2010G, UNG00A, ZN504XG-D, ZN515XG-D, HM2004-DU," >&2
    echo "          XG-040G-MF, XG-040G-MF-UBI" >&2
    exit 1
    ;;
esac

CONFIG_SRC="$PONWRT_DIR/configs/${SOC}.config"
RELEASE_CFG="$PONWRT_DIR/configs/release.config"
IMAGE_MK="$PONWRT_DIR/target/linux/airoha/image/${SOC}.mk"
CONFIG_FILE="$PONWRT_DIR/.config"

[ -f "$CONFIG_SRC" ] || { echo "错误：缺少配置文件 $CONFIG_SRC" >&2; exit 1; }
[ -f "$IMAGE_MK" ]   || { echo "错误：缺少 image Makefile $IMAGE_MK" >&2; exit 1; }

# profile 必须真的存在于对应 SoC 的 image Makefile 里，防止映射写错
if ! grep -qE "^TARGET_DEVICES \+= ${PROFILE}$" "$IMAGE_MK"; then
  echo "错误：$IMAGE_MK 中找不到设备 profile: $PROFILE" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 生成基础 .config
#   PonWrt 官方 release 工作流用 kconfig.pl 合并 configs/release.config，
#   这里保持一致，额外带上 kmod-wireguard、luci-app-upnp 等 release 包。
# -----------------------------------------------------------------------------
if command -v perl >/dev/null 2>&1 && [ -f "$RELEASE_CFG" ] && [ -f "$PONWRT_DIR/scripts/kconfig.pl" ]; then
  ( cd "$PONWRT_DIR" && perl scripts/kconfig.pl + "configs/${SOC}.config" "configs/release.config" ) > "$CONFIG_FILE"
else
  cp -f "$CONFIG_SRC" "$CONFIG_FILE"
  if [ -f "$RELEASE_CFG" ]; then
    cat "$RELEASE_CFG" >> "$CONFIG_FILE"
  fi
fi

# -----------------------------------------------------------------------------
# 只保留目标设备
#   删除所有 CONFIG_TARGET_DEVICE_* / CONFIG_TARGET_DEVICE_PACKAGES_*，
#   同时删除旧式 Target Profile 选择项，避免 defconfig 保留多个设备。
# -----------------------------------------------------------------------------
sed -i -E \
  -e '/^#? ?CONFIG_TARGET_DEVICE_[A-Za-z0-9_]+_DEVICE_/d' \
  -e '/^#? ?CONFIG_TARGET_airoha_(an7581|an7583)_DEVICE_/d' \
  "$CONFIG_FILE"

# 确保多设备模式打开（configs/*.config 默认就是 y）
sed -i -E '/^#? ?CONFIG_TARGET_MULTI_PROFILE(=| is not set)/d' "$CONFIG_FILE"
echo 'CONFIG_TARGET_MULTI_PROFILE=y' >> "$CONFIG_FILE"

# 确保每个设备单独构建 rootfs（PonWrt 官方 config 的默认值）
if ! grep -q '^CONFIG_TARGET_PER_DEVICE_ROOTFS=y$' "$CONFIG_FILE"; then
  echo 'CONFIG_TARGET_PER_DEVICE_ROOTFS=y' >> "$CONFIG_FILE"
fi

# 只追加目标设备
{
  echo "CONFIG_TARGET_DEVICE_airoha_${SOC}_DEVICE_${PROFILE}=y"
  echo "CONFIG_TARGET_DEVICE_PACKAGES_airoha_${SOC}_DEVICE_${PROFILE}=\"\""
} >> "$CONFIG_FILE"

# -----------------------------------------------------------------------------
# 输出给 GitHub Actions 后续步骤
# -----------------------------------------------------------------------------
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "soc=${SOC}"
    echo "profile=${PROFILE}"
    echo "device=${DEVICE}"
    echo "config=configs/${SOC}.config"
  } >> "$GITHUB_OUTPUT"
fi

echo "已选择设备: ${DEVICE}"
echo "  平台: airoha/${SOC}"
echo "  Profile: ${PROFILE}"
echo "  基础配置: ${CONFIG_SRC}"
echo "  生成配置: ${CONFIG_FILE}"
