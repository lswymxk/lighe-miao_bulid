#!/bin/sh
# =============================================================================
# 可选的自定义脚本
#
# 执行时机：feeds 安装完成、设备 .config 生成之后，make defconfig 之前
# 当前目录：ponwrt/
#
# 在这里追加的 CONFIG_PACKAGE_* 会被 make defconfig 解析并补齐依赖。
# 也可以在这里修改 feeds 里的源码（例如换主题、改默认设置）。
#
# 示例：
#   echo 'CONFIG_PACKAGE_luci-app-argon-config=y' >> .config
#   echo 'CONFIG_PACKAGE_luci-theme-argon=y' >> .config
#   sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
#
# 不需要自定义时保持本文件为空（只有注释）即可。
# =============================================================================
