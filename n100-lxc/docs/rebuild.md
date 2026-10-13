# 源码重建与稳定版升级

所有下载、工具前缀、临时目录、Go/Rust/ccache、日志和产物位于唯一项目根目录
`/data/disk2/lyy_dataset/openwrt/`。使用系统已有 GCC/G++/make/git/Python；
缺失的辅助工具由 `host-debs.json` 固定版本与 SHA256，解包到项目前缀，无需 root。
`project-env.sh` 清理 Conda 编译/库变量，使用系统 Python 3.8，并不修改 HOME/CODEX_HOME。
构建需要系统 GCC >=8、GNU make >=4.1 等，首次执行 `make prereq` 核验。
下载的 `.deb` 仅是编译服务器工具依赖；模板用户态核心和 OpenWrt 工具链从源码构建。
Go bootstrap 配方从 Go 1.4 C 引导及固定源码逐级构建；不把系统 Go 当成目标构建 Go。

```sh
cd /data/disk2/lyy_dataset/openwrt/repos/openwrt
source n100-lxc/scripts/project-env.sh
python3 n100-lxc/scripts/prepare-host.py
bash n100-lxc/scripts/prepare-source.sh
JOBS=32 bash n100-lxc/scripts/build.sh
bash n100-lxc/scripts/release.sh
OUT=$(cat "$PROJECT_ROOT/work/latest-release.txt")
bash n100-lxc/scripts/verify-userspace.sh "$OUT"
bash n100-lxc/scripts/verify-xray-patches.sh "$OUT"
python3 n100-lxc/scripts/audit-binaries.py "$(cat "$PROJECT_ROOT/work/last-userspace-root.txt")" --report "$OUT/binary-audit.json"
python3 n100-lxc/scripts/verify-generated-configs.py "$OUT/generated-test-configs" --report "$OUT/generated-config-verification.json"
python3 n100-lxc/scripts/verify-inputs.py --require-all
```

从空目录重建时将 fork 克隆到项目的 repos/openwrt 并检出 BUILD-INFO 中的 commit；
确认其 upstream 为官方 https://github.com/openwrt/openwrt.git，origin 为用户 fork。
feeds.conf 中采用官方稳定版固定 commit，Go 配方与第三方配方已纳入版本控制。
prepare-source 显式排除重复提供方的 feed 链接；providers.json 是来源选择依据。
prepare-source 还会执行 `scripts/apply-source-patches.sh`：Passwall2 的
`patches/passwall2-nofile.diff` 仅设置软上限 65535，保留宿主提供的硬上限。
已应用的补丁可重复执行；上游源码发生不兼容变化时停止并要求审查，不静默略过。
更新 Passwall2 配方时保留本地 PKG_RELEASE 后缀，并同步清单版本检查。
`patches/openclash-lxc.diff` 保留 OpenClash 的 procd 文件句柄限制和缺失数值选项适配。
读取 `/proc/1/limits` 的硬上限，软上限取 `min(65535, 硬上限)`，无法读取时使用
启动 shell 的硬上限；不强行提高 nproc、memlock 或地址空间限制。更新 OpenClash
配方后重新应用补丁，并保留本地 PKG_RELEASE，当前包为 `0.48.002-r1`。
仅在 UCI 选项不存在时补 `auto_restart=0` 和 `chnr_auto_update=0`，保留已有值。
镜像不再带 `n100-direct-example.yaml`；现有 CI 检查在 `/tmp/checks/` 生成独立配置，
不依赖镜像中预先存在的示例，也不将订阅或现网配置写入公开源码。
ZeroTier LuCI 从 ImmortalWrt 固定 commit 单独移植，没有引入其基础包源；
`patches/zerotier-luci-openwrt.diff` 记录官方 OpenWrt 启动脚本所需的界面适配。
入口为“服务 → ZeroTier”，种子必须同时选择主程序、LuCI 和中文语言包。
OpenClash 核心复制自同一次源码编译的 Mihomo，数据来自 checksum 固定的 GeoIP/GeoSite。
Xray SSR 专用补丁原样保留，仅移除 UPX；兼容性证据见验证报告，现网节点另验。

锁文件中的 downloaded-sources/Go 模块校验值用于审计实际输入。归档数据和缓存可
单独保留供离线重建；缓存不是版本控制的一部分。原始研究基线的 null 标注不参与构建。
默认 32 个并行任务适用于本次服务器；其他机器按内存和共享负载调整。构建驱动每
30 秒记录资源，低于 20 GiB 可用空间即停止。不要清理别人的项目，也不要全局安装工具。

## 更新 SSR 和其他第三方包

`package/n100-lxc/` 是上游固定提交的源码快照，不会随 `git pull` 或
`scripts/feeds update -a` 自动同步。SSR 核心的上游包本身包含完整 `src/`，所以导入
文件较多；它与 SSR Plus+ 界面来自不同仓库，需要分别选择更新版本。

| 包 | 上游仓库 | 仓库内目录 |
| --- | --- | --- |
| SSR Plus+ 界面 | `fw876/helloworld` | `luci-app-ssr-plus` |
| SSR 核心 | `Openwrt-Passwall/openwrt-passwall-packages` | `shadowsocksr-libev` |
| Passwall2 界面 | `Openwrt-Passwall/openwrt-passwall2` | `luci-app-passwall2` |
| OpenClash 界面 | `vernesong/OpenClash` | `luci-app-openclash` |

当前没有自动跟随第三方最新版的更新脚本。以 SSR 为例，先提交或保存本地修改，
再从上游选定要采用的完整 40 位 commit SHA。以下命令只导出候选源码到项目 work
目录，供检查；将两个变量中的占位文字替换为选定的 SHA：

```bash
cd /data/disk2/lyy_dataset/openwrt/repos/openwrt
source n100-lxc/scripts/project-env.sh
SSR_UI_COMMIT=替换为界面仓库的完整提交SHA
SSR_CORE_COMMIT=替换为核心仓库的完整提交SHA
SSR_UPDATE_DIR=$(mktemp -d "$PROJECT_ROOT/work/ssr-update-XXXXXX")
mkdir -p "$SSR_UPDATE_DIR/ui" "$SSR_UPDATE_DIR/core"
git -C "$PROJECT_ROOT/repos/helloworld" fetch origin "$SSR_UI_COMMIT"
git -C "$PROJECT_ROOT/repos/helloworld" archive "$SSR_UI_COMMIT" luci-app-ssr-plus |
  tar -x -C "$SSR_UPDATE_DIR/ui"
git -C "$PROJECT_ROOT/repos/passwall-packages" fetch origin "$SSR_CORE_COMMIT"
git -C "$PROJECT_ROOT/repos/passwall-packages" archive "$SSR_CORE_COMMIT" shadowsocksr-libev |
  tar -x -C "$SSR_UPDATE_DIR/core"
```

上述两个上游 clone 已在本工作区的 repos 中；新机器需先按表中地址克隆。
检查上游变更和依赖后，用导出的两个目录分别完整替换对应的
`package/n100-lxc/` 目录，避免只覆盖文件而遗留上游已删除的文件。
只更新所选包，不覆盖整个 helloworld，否则可能丢失 Xray 的 SSR 专用补丁及本地适配。

同步更新 `locks/providers.json` 中这两个包的 `recipe_commit`。因为同一仓库还提供
其他固定旧版本的包，单独更新 SSR 时，在 `locks/repositories.json` 增加各自独立的
仓库记录（例如 `luci-app-ssr-plus-recipe` 和 `shadowsocksr-libev-recipe`），记录 URL、
commit 和许可证；不要把仍被其他包使用的旧仓库 commit 或 tag 改成新版本。
同时按新配方的版本调整 `scripts/verify-manifest.py` 中 SSR Plus+ 的预期版本，
以及受依赖变化影响的种子配置。

更新 Passwall2、OpenClash、ZeroTier 等有本地补丁的包后，执行
`bash n100-lxc/scripts/apply-source-patches.sh`；补丁冲突必须解决后才能构建。
然后运行 `JOBS=32 bash n100-lxc/scripts/ci-build.sh` 完整重建和回归。该脚本会重新
生成 source-lock 和源码哈希；检查 `git diff`，将源码、配方、锁和验证结果一起提交。
推送维护分支会自动运行 GitHub Actions；自动构建使用已提交的固定版本，不自动升级上游。

## 升级 OpenWrt 稳定版

先检查 `git status`，有修改必须提交或另行保存，不自动覆盖。运行
`bash n100-lxc/scripts/upgrade-stable.sh [vXX.YY.Z]`：仅接受正式稳定 release，
fetch 该 tag，在项目 work 内创建新分支/工作树，按顺序 cherry-pick 定制提交，并更新
系统和官方 feeds 锁。脚本不会将 main 合并进生产分支，不强推；冲突留在升级工作树处理。

升级工作树保留经过验证的插件/工具链固定版本，以降低同时升级的变量。用官方 release
API 检查各插件、核心与 Go 要求；需要升级时更新 vendored 配方、providers、仓库锁和
数据校验值，检查 Xray 专用补丁和三个生成器，再执行完整重建/验证并生成新 source-lock。
不要只替换浮动 tag，也不要在锁中留下 null、main/master。通过回归后将升级分支提交、
推送到 fork；生产分支是否采用新模板由目标验收决定。

回归包含归档布局/所有权/权限、包清单、核心版本/配置、模板启动、DNS/nftset、
TCP/UDP 透明代理、策略路由/TUN/TAP、三个插件启停清理、ZeroTier 和隔离 KMS。
保存旧模板和旧锁；依照 pve-install.md 新建测试 CT 后迁移，使用备份/旧 CT 回滚。
本次未执行一个未来 OpenWrt 版本的完整升级编译；脚本当前稳定版检查与语法核验必须如实记录。

正常 apk 诊断包安装与签名仓库保留。升级 ubox、dnsmasq、vlmcsd 等基础包可能覆盖
模板后处理的文件；此时执行 `lxc-adaptation-check` 检查并重新应用相应定点适配。
基础系统/代理核心升级优先使用重新构建的新模板和完整回归，不把未测的任意 apk upgrade
当成已验证 CT 升级路径。此文件覆盖风险在当前架构中保留，报告不得省略。

时间戳使用稳定 tag 中发布的 version.date，与 OpenWrt 构建系统一致；缺少该文件
时才使用 tag 指向 commit 的时间，签名 tag 必须先解引用。同一原始归档的重复后处理
校验不等于独立空缓存源码重建逐字节相同；后者本次没有执行。

实测缓存重建时，GNU readline 安装会产生 .so.old 备份。维护分支的独立小补丁在
Build/Install 后移除这些包装临时副本，保留实际共享库；已强制重装验证。归档检查
会拒绝这类备份。升级脚本更新官方包提供方的 base commit；新基线若改变 GCC/binutils，
配置审计会要求先更新 toolchains.json 的版本、来源和 SHA256，避免沿用旧编译器记录。

PRoot 检查仅虚拟化文件路径，仍共享编译服务器内核、PID/网络环境。测试仅启动
项目内 Unix socket 的 ubus/rpcd，以便实际 LuCI UCI 接口生成配置；为 SO_PEERCRED
在解包测试副本追加当前 UID/GID 和 0644 临时 ACL，记录到 userspace-test-adjustments.json。
不运行 procd/init 或代理监听。目标启动、服务、权限和数据流行为须另行验收。

自定义代理包不是官方仓库同名包的可互换升级：特别是 Xray 包含 SSR 专用补丁。
不要直接用官方同名核心覆盖本模板的锁定核心。升级这些包时使用维护分支源码重建，
或者建立经过签名和兼容性验证的自有包源；本次没有发布自有在线包源。
交付目录中的 scripts/docs/locks 是审查副本；完整重建应在上述 fork 工作树执行，
其中还包含固定的 package/n100-lxc 和 toolchain/golang 配方。

本机已有 OAuth 凭证缺少 workflow scope，不能推送带上游工作流的维护分支。
已有 GitHub SSH 认证可用，因此 origin 的获取地址保持 HTTPS、推送地址使用同一
fork 的 SSH 地址；不扩大 OAuth 授权，也不删除上游工作流。换机时核对已有 Git
认证，推送后用远程分支 SHA 与本地 HEAD 对照，不能只凭命令启动就报告成功。
