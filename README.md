# lighe-miao_bulid

基于 GitHub Actions 的 **PonWrt 云编译项目**。工作流参考
[lswymxk/build-openwrt-with-actions](https://github.com/lswymxk/build-openwrt-with-actions)
仓库 `25.12` 分支的 `build_immortalwrt.yml`，源码来自
[pbs05/ponwrt](https://github.com/pbs05/ponwrt)。

- **只手动触发**：`on: workflow_dispatch`，不随 push、定时任务自动编译。
- **编译前释放磁盘空间**：先删除 runner 镜像里的大件与缓存；双盘布局再合并
  `/` 与 `/mnt`，单盘布局跳过，避免把根分区压爆。
- **手动选择设备型号**：默认 **XG-040G-MD**（Nokia XG-040G-MD UBI / AN7581）。
- **一次只编一个机型**：自动从 `configs/an7581.config` 或
  `configs/an7583.config` 生成 `.config`，删除其他设备，只保留所选设备。
- **产物可下载**：固件上传到 Artifact，编译日志和最终 `.config` 另外存档。

## 支持的设备

| 设备型号（下拉选项） | SoC | PonWrt Profile |
| --- | --- | --- |
| `XG-040G-MD`（默认） | AN7581 | `nokia_xg-040g-md-ubi` |
| `XG-040G-TF` | AN7581 | `nokia_xg-040g-tf-ubi` |
| `HG5382A` | AN7581 | `fiberhome_hg5382a` |
| `HG5585F-CT` | AN7581 | `fiberhome_hg5585f-ct` |
| `HG5585F-CU` | AN7581 | `fiberhome_hg5585f-cu` |
| `XG2010G` | AN7581 | `gemtek_xg2010g` |
| `UNG00A` | AN7581 | `unionman_ung00a` |
| `ZN504XG-D` | AN7581 | `znxt_zn504xg-d` |
| `ZN515XG-D` | AN7581 | `znxt_zn515xg-d` |
| `HM2004-DU` | AN7581 | `h3c_hm2004-du` |
| `XG-040G-MF` | AN7583 | `nokia_xg-040g-mf` |
| `XG-040G-MF-UBI` | AN7583 | `nokia_xg-040g-mf-ubi` |

设备与 SoC/profile 的映射在 [`scripts/select-device.sh`](scripts/select-device.sh)。
上游新增设备时，需要同时修改：

1. 本文件表格；
2. `.github/workflows/build_ponwrt.yml` 里 `device.options`；
3. `scripts/select-device.sh` 里的 `case` 映射。

脚本会检查 profile 是否真的存在于
`target/linux/airoha/image/<soc>.mk`，映射写错会直接失败，不会静默编错固件。

## 目录结构

```text
.
├── .github/workflows/build_ponwrt.yml   # 云编译工作流
├── scripts/
│   ├── select-device.sh                 # 设备映射 + 生成单设备 .config
│   └── verify-config.sh                 # defconfig 后校验只启用一个设备
├── diy.sh                               # 可选自定义（feeds 之后、defconfig 之前）
└── README.md
```

## 使用方法

1. 在 GitHub 新建仓库，仓库名建议就是 `lighe-miao_bulid`。
2. 把本目录推送到仓库默认分支（通常是 `main`）：

   ```bash
   git init
   git add .
   git commit -m "init: PonWrt cloud build"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/lighe-miao_bulid.git
   git push -u origin main
   ```

3. 打开仓库 **Actions** → 左侧 **🚀 编译 PonWrt (Build PonWrt)** →
   **Run workflow**。
4. `设备型号` 保持默认 `XG-040G-MD`，或选择其他机型；需要调试可勾选
   `启用 SSH 调试`，然后点击 **Run workflow**。
5. 编译完成后，在本次运行页面底部下载：
   - `PonWrt-<profile>-<run_number>`：固件（`.itb` / `.bin` / `.tar` /
     `.sha256` / `profiles.json`）；
   - `PonWrt-logs-<run_number>`：`build.log`、最终 `.config`、
     `feeds.conf.default`。

## 工作流做了什么

1. **释放磁盘空间**
   - 删除 `/usr/share/dotnet`、Android SDK、`/opt/ghc`、CodeQL、Boost、
     Azure CLI、Swift 等大件；
   - 清理 Docker 镜像、APT 缓存与包列表；
   - 检测 `/` 与 `/mnt` 是否同一设备：双盘时用
     `easimon/maximize-build-space` 合并，单盘时跳过；
   - 每一步前后打印 `df -hT`，方便确认空间。
2. **安装依赖**：使用 PonWrt README / 参考工作流中的完整依赖列表。
3. **拉取源码**：`pbs05/ponwrt`，默认 `master`，浅克隆。
4. **feeds**：`./scripts/feeds update -a && ./scripts/feeds install -a`。
5. **生成单设备配置**
   - 用 `scripts/kconfig.pl` 合并 `configs/<soc>.config` 与官方
     `configs/release.config`（带上 release 包）；
   - 删除所有 `CONFIG_TARGET_DEVICE_*`，只追加所选设备的
     `CONFIG_TARGET_DEVICE_*` 与 `CONFIG_TARGET_DEVICE_PACKAGES_*`；
   - `make defconfig` 补齐依赖；
   - 校验 `.config` 里确实只有一个设备，否则失败。
6. **编译**：`make download -j$(nproc)` 预下载，然后
   `make -j$(nproc)`（可切换单线程），完整日志写入 `build.log`。
7. **上传**：固件和日志分别作为 Artifact 保存；Job Summary 输出设备、
   Profile、提交号和文件列表。

## 可选自定义

编辑根目录 [`diy.sh`](diy.sh)，它在 feeds 安装之后、`make defconfig`
之前执行，当前目录是 `ponwrt/`。适合追加软件包、换主题、改默认配置等，例如：

```sh
echo 'CONFIG_PACKAGE_luci-theme-argon=y' >> .config
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
```

## 本地检查

```bash
# YAML / 表达式检查（需要 actionlint）
actionlint .github/workflows/build_ponwrt.yml

# Shell 脚本检查（需要 shellcheck）
shellcheck scripts/select-device.sh scripts/verify-config.sh diy.sh

# 查看设备映射（需要一份 ponwrt 源码）
./scripts/select-device.sh XG-040G-MD ./ponwrt
./scripts/verify-config.sh an7581 nokia_xg-040g-md-ubi ./ponwrt/.config
```

## 说明

- 首次完整编译通常需要 **2～4 小时**，工作流超时设置为 360 分钟。
- 编译使用 GitHub 托管 runner，会消耗 Actions 额度；私有仓库尤其注意。
- 固件默认保留 30 天，日志保留 14 天，可在工作流里调整。
- PonWrt 上游的 `configs/*.config` 已包含 LuCI、PON 驱动、PON 用户态工具等；
  本项目只做“单设备裁剪 + release 包合并”，不改变 PonWrt 的默认功能。
- 刷机有风险，请先备份原厂固件与校准数据，并确认设备型号与 Profile 匹配。

## 参考

- [lswymxk/build-openwrt-with-actions（25.12 分支）](https://github.com/lswymxk/build-openwrt-with-actions/tree/25.12)
- [pbs05/ponwrt](https://github.com/pbs05/ponwrt)
- [PonWrt 支持的设备](https://github.com/pbs05/ponwrt#supported-devices)
