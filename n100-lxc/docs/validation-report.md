# 本次源码编译与验证报告

2026-10-13 已在当前编译服务器实际完成源码编译，并生成 PVE LXC 用途的 rootfs
归档。归档布局、权限、包清单、核心执行和配置校验通过。PRoot 检查共享编译服务器
的内核、PID 和网络，不能算作 CT 隔离测试。目标 PVE/N100 尚未验收；按用户最新
要求，本次没有执行 QEMU 启动或客体测试。

## OpenClash 启动资源限制修复（待 GitHub 重建）

按工作区根目录的 `OPENCLASH_REBUILD_PROMPT.txt` 和 `openclash-lxc-nofile.patch`
修改既有固定版源码，未升级 OpenWrt、Mihomo、Ruby/YAML 或其他依赖。用户报告的
目标 CT 已修复；该报告属于用户侧运行记录，本轮不据此宣称新镜像已验收。

- 新的 `patches/openclash-lxc.diff` 记录 init、UCI 默认值和本地包 release 适配，
  在源码准备阶段自动检查应用，并登记到 providers/source-lock。
- `/proc/1/limits` 提供 procd 的 nofile 硬上限；软上限取与 65535 中的较小值，
  shell 仅执行 `ulimit -Sn`。procd 只设置该软上限及已有硬上限，移除 nproc、
  memlock 和地址空间的强制提升；本地包版本为 `0.48.002-r1`。
- 原配置增加 `auto_restart=0`、`chnr_auto_update=0`；安装初始化只补缺失选项，
  不覆盖已有值。对应 cron 比较改为字符串判断，避免空值参与整数比较。
- 删除镜像内的 `n100-direct-example.yaml`，并同步修改所有引用它的验证脚本：
  GitHub 原有用户态检查在临时目录创建同等独立配置，目标辅助脚本也只写临时目录。
- 2026-10-13 上一轮 GitHub
  [38395499180](https://github.com/yvanliang/openwrt/actions/runs/38395499180)
  对提交 `f9ef2e29d9a968893f182147488d435e8fe7dca6` 完整构建、验证和发布成功；
  该版本尚不包含本次 OpenClash 修复。
- 用户最新指示为“不执行测试，按提供的修改实施”。本轮不执行额外本地运行测试、
  PVE/CT start/restart 或生产环境操作；仅做源码和语法检查，保留原有 GitHub
  构建校验流程。新镜像的依赖版本、SHA256 和 CI 结果以新 Actions 的交付为准。

## 前次 Passwall2 / ZeroTier 修复交付

- Build ID：`25.12.5-n100-lxc-20261013T072645Z-af1f67c087a3`。
- 模板代码提交：`af1f67c087a3d4b8bb8c0d9fd6dd1b0145808606`。
- 目录：`/data/disk2/lyy_dataset/openwrt/artifacts/25.12.5-n100-lxc-20261013T072645Z-af1f67c087a3/`，模板 `rootfs.tar.gz`，114596477 字节。
- SHA256：`7fdf714519038d28aa0e2ad691b7b7f08a9a2fed8685a8ff8517da358b92aec8`。
- 构建日志：`logs/build-20261013T072300Z.log`；构建和验证入口完整日志：
  `logs/ci-nofile-zerotier-fix.log`。
- 归档 40 项检查、198 包 manifest、核心执行/配置、Xray 专用补丁回归
  及 2956 项输入校验全部通过；缺失和校验不符均为 0。

Passwall2 上游 `ulimit -n 65535` 同时降低软、硬上限。已改为
`ulimit -Sn 65535`，本地包版本为 `26.10.1-r3`，区别于未修复的上游 r2。
补丁 `patches/passwall2-nofile.diff` 已在锁文件登记，源码准备时自动检查并应用。
已验证补丁可应用到固定上游源码，并可重复执行。实际模板 BusyBox 对照测试中，
旧命令得到软/硬上限 65535/65535；修改后得到 65535/524288，子进程可提高软上限
至 100000，硬上限仍为 524288。这是编译机子进程测试；用户反馈的目标 CT A/B
测试是本次修复依据，本轮没有重新连接 PVE 进行实测。

此前仅装 ZeroTier 核心，确实遗漏 LuCI。本次增加 `luci-app-zerotier` 和
`luci-i18n-zerotier-zh-cn`，入口为“服务 → ZeroTier”。从 ImmortalWrt LuCI
commit `5fc1fac5684cac6eee2c7fbff78c65b867980dd8` 单独移植，保留官方 OpenWrt
ZeroTier 1.16.0 服务。兼容性补丁去掉该服务不支持的网络启用/自动防火墙字段，
避免界面保存后无效果，并校验 16 位网络 ID。菜单、ACL、两个 JS 页面、中文翻译
和默认无身份/无预加入网络均通过归档检查；JS 语法和离线表单构造检查通过。
浏览器页面、服务启动和授权组网仍需在目标 CT 验证。

## GitHub Actions 文件句柄回归测试修正

运行 [38367673854](https://github.com/yvanliang/openwrt/actions/runs/38367673854)
使用提交 `0f10cc9dde240c3accec4a5e0e3707de31800def`。源码编译、归档检查和
198 包清单检查已通过；失败发生在 PRoot 用户态验证的 `passwall-nofile.sh`，
错误为 `sh: error setting limit: Invalid argument`，因此未发布 Release。

旧测试直接执行 `ulimit -Sn 524288` 和 `ulimit -Hn 524288`，把目标 PVE 的测试
数值当成了所有编译环境都提供的上限。构建日志未记录该 runner 的具体 nofile
上限；本地将测试子进程硬上限限制为 65536 后，旧脚本完整复现了同一错误。
修正后读取并保留实际继承的硬上限，检查旧命令会把软、硬上限都降到 65535，
以及实际打包的修复命令只设置软上限。子进程提高软上限的测试值取 100000 与
宿主硬上限中的较小值；硬上限必须保持不变。宿主硬上限不超过 65535 时明确
报错，要求提供足够测试空间，不跳过此项回归。

2026-10-13 本地使用模板中的 BusyBox 和 PRoot 实测：

| 用例 | 结果 |
| --- | --- |
| 旧测试，硬上限 65536 | 复现 Invalid argument，退出 1 |
| 新测试，硬上限 65536 | 保留硬上限，子进程软上限可提高到 65536 |
| 新测试，硬上限 524288 | 保留硬上限，子进程软上限可提高到 100000 |
| 新测试，硬上限 1048576 | 保留硬上限，子进程软上限可提高到 100000 |
| 新测试，硬上限 65535 | 按预期明确报错，退出 1 |
| 完整用户态验证，硬上限 65536 | 核心执行、配置生成和默认配置检查全部通过 |

证据：`logs/github-failure-38367673854/failed-steps.log`、
`nofile-regression-matrix.log` 和 `full-userspace-65536.log`。这次只修正验证脚本，
并在 hosted-runner 准备日志增加实际继承的 nofile 软、硬上限；Passwall2 的
`ulimit -Sn 65535` 修复和 ZeroTier LuCI 源码未变。新 Actions 的结果需要单独确认。

以下内容保留为此前构建记录及回滚依据，旧模板没有上述两项修复。

## 首次交付（保留用于回滚）

- Build ID：`25.12.5-n100-lxc-20261013T063414Z-9f63f938fda3`。
- 目录：`/data/disk2/lyy_dataset/openwrt/artifacts/25.12.5-n100-lxc-20261013T063414Z-9f63f938fda3/`。
- 模板：`rootfs.tar.gz`，114595958 字节，约 109.3 MiB。
- 模板 SHA256：`93ee1d341c59c498ac3a35170cd23a9edbc41bf6502d98c76060210820b95a51`。
- 原始源码编译归档 SHA256：`715db06cb03a590bcfa90aaea7150d5d05ce135b3472c473f5743eda5c3113fb`。
- 模板代码提交：`9f63f938fda3`；完整提交及最终文档交付提交见目录中的 `BUILD-INFO`。
- fork：[yvanliang/openwrt](https://github.com/yvanliang/openwrt)，维护分支
  `n100-pve-lxc/25.12.5`；origin 指向该 fork，upstream 指向官方 OpenWrt。
  交付中的 `github-remote-verification.json` 记录推送后远程分支与本地提交一致性。

同目录还包括 `SHA256SUMS`、最终 `final.config`、`diffconfig`、196 包完整 manifest、
源码/工具链/提供方/数据/宿主依赖锁、构建和验证脚本、目标辅助程序及本报告。
`evidence/` 保存验证结果和选定日志；完整历史日志保留在项目 `logs/`，包括定位失败
的日志。更早的 artifacts 目录是中间候选，不是本次最终交付。

## 源码、环境和修复

已完整阅读用户提示以及同目录构建方案、配置骨架、PVE 预检查、版本研究基线。
当前机器为 `liangyy`，用户 dancer，Ubuntu 20.04.6，真实运行内核
`6.8.0-57-generic`，Xeon Platinum 8336C，128 逻辑 CPU、约 503 GiB RAM。
使用系统 GCC 9.4/Python 3.8，隔离 Conda 的 PATH、头文件及动态库变量。
缺失依赖通过 22 个固定 SHA256 的 deb 解包到 `work/tools/prefix`，无全局安装、
无 HOME/CODEX_HOME 修改。所有新增环境、源码、缓存、临时文件、日志和产物位于
用户指定项目目录。下载的宿主工具 deb 不属于模板目标二进制。

初始共享磁盘约 96 GiB 可用，交付时约 63 GiB 可用，inode 使用约 7%。构建使用
32 并行任务，每 30 秒记录资源，低于 20 GiB 可用空间停止整个 make 进程组；
进程组终止机制已实际检查。未取得独立的用户配额信息，未删除其他项目文件。
完整源码构建成功日志为 `logs/build-20261013T051729Z.log`，readline 修复后完整
缓存构建成功日志为 `logs/build-20261013T060534Z.log`。

| 组件 | 本次固定选择 | 依据与处理 |
|---|---|---|
| OpenWrt | v25.12.5 | 官方稳定 release，完整 commit 固定 |
| Passwall2 | 26.10.1-2 | 正式 release |
| SSR Plus+ | v196.19 | 正式 release，独立 UI 与 SSR libev 客户端 |
| OpenClash | v0.48.002 | 正式 release，Ruby/YAML 及离线规则数据预装 |
| Mihomo | v1.19.32 | 本机源码编译，核心路径与权限已校验 |
| sing-box | v1.14.3 | 官方稳定版比研究基线 1.14.2 更新，实际生成配置校验通过 |
| Xray | 26.9.30-r5 | SSR 配方的三个专用补丁全部保留，作为共享核心 |
| Go | 1.27.1 | 固定 packages 配方提交，完整源码 bootstrap 链 |
| GCC/binutils/musl | 14.3.0 / 2.44 / 1.2.5 | OpenWrt 源码工具链 |
| ZeroTier / HAProxy / dnsmasq / Ruby | 1.16.0 / 3.2.15 / 2.93 / 3.4.9 | 真实模板程序版本输出已检查 |
| vlmcsd | 固定 2020-03-30 源码 commit | 仅移植锁定 ImmortalWrt 单包配方 |

上述六个应用/系统的官方 latest release API 返回均为非 draft、非 prerelease，
原始响应在 `evidence/release-evidence/`。完整仓库 commit、配方、源压缩包 SHA256、
许可证见 `locks/` 和 `source-lock.json`；构建锁没有 null 或浮动分支引用。
Go 从 1.4 C bootstrap 经 1.17.13、1.20.14、1.22.12、1.24.13 源码构建到 1.27.1，
不是服务器系统 Go。所有模板核心、OpenWrt 工具链和安装用户态代码均由源码构建。

实际修复包括：补齐本地 gettext 依赖；宿主辅助工具头文件使用低优先级搜索，避免
旧 ncurses 覆盖源码新版本；关闭不处于代理数据路径的 Ruby YJIT，保留 YAML，
最终模板不依赖 Rust；去掉 Xray/Mihomo 的 UPX 后处理，保留协议补丁；对签名 tag
正确取发布 `version.date=1782737960`；修复 GNU readline 再安装时产生的 `.so.old`
备份污染，并强制重新编译/安装确认不再出现。包提供方有显式映射，重复 feed 链接
已排除。最终 required_missing、seed_y_dropped、compiler_lock_mismatch 均为空。
最后关闭 HAProxy 独立 init 的默认示例自启动；保留核心以及 PW2 自行生成配置、
启动负载均衡的路径。此项通过归档检查，真实节点负载均衡仍待目标验收。
构建仍提示未选中的可选 SSR 协议包和视频 feed 依赖不存在；本次选定依赖和 manifest
检查通过，这些警告不代表那些可选协议已安装。

## 实际验证证据与边界

| 验证层次 | 实际状态 | 证据与边界 |
|---|---|---|
| 源码编译 | 通过 | 原始 generic rootfs、包产物和完整 make 日志存在 |
| 最终归档/包清单 | 通过 | 35 项静态检查、196 包必需版本清单 |
| 输入校验 | 通过 | 1667 下载输入 + 1255 配方文件 + 22 宿主 deb，共 2944，缺失/不符均为 0 |
| 脚本与锁 | 通过 | 10 Python、14 shell 语法检查，构建锁 null 数为 0 |
| 用户态核心执行 | 通过 | 最终归档解包后的 PRoot 版本/配置检查，运行编译服务器 6.8 内核 |
| Xray SSR 补丁回归 | 通过 | AnyTLS、allowInsecure、legacy VMess 配置/编解码测试；见测试日志 |
| 同输入重复后处理 | 通过 | 两次输出 SHA256 相同，见 delivery-evidence.json |
| 独立空缓存源码重建逐字节一致 | 未执行 | 缓存重建并不证明该项 |
| CT 隔离启动、服务及网络 | 未执行 | 本机无可用非 root 容器/网络命名空间权限；PRoot 不提供隔离 |
| QEMU | 未执行，用户暂停 | 早期工具版本探测没有启动内核或客体，不计测试通过 |
| PVE 7.0.14-8-pve | 未执行 | 内核版本来自用户，尚未读取目标 config/功能结果 |
| N100 吞吐、资源及指令调度 | 未执行 | 编译机 Xeon 的任何结果不作为 N100 验收 |

归档直接包含 bin/etc/sbin 等，保存 UID/GID、符号链接、执行权限，不含 GRUB/EFI
或整盘镜像。OpenClash `clash_meta` 为同次源码 Mihomo 的逐字节副本，0755。
GeoIP/GeoSite DAT 和 Country.mmdb 已预置，真实 Mihomo 对 DAT/MMDB 中的 CN 规则
离线加载及配置检查通过。Country 数据包含 MaxMind 相关数据来源，不能将构建脚本
的 MIT 许可证概括成全部数据库数据许可证；来源和说明保留在数据锁中。

核心 ELF 记录均为 GOAMD64=v1，无 march=native。Xray/sing-box 各检出 786 条 AES
及 161 条 PCLMUL 指令，Mihomo 检出 1981/238 条；其 SHA256 与最终解包核心一致。
这证明加速代码路径存在，不证明 N100 已执行该路径或达到吞吐目标。

PRoot 中仅启动项目内 Unix socket 的 ubusd/rpcd，以真实 LuCI UCI/RPC 接口生成配置，
没有用假的 Lua UCI 实现替换生成器。SO_PEERCRED 保留宿主 UID 1000，因此仅在测试
解包副本追加用户/组和临时 ACL，调整记录随交付保存；原模板不含该测试授权。
没有启动 procd/init、代理监听、fw4 或 ZeroTier/KMS 服务。Xray 补丁单元测试使用
net.Pipe 或构建服务器回环端口，是协议/实现回归，不是外部节点或 CT 网络测试。

实际检查了 PW2 Xray、PW2 sing-box、SSR SOCKS 和 SSR AnyTLS 生成配置，由对应
源码核心原生检查通过。7 项 DNS 目的地/直连 detour/FakeDNS/IPv4 查询静态检查通过。
这些使用合成节点，并不等同当前三个真实节点、HAProxy 负载均衡或完整双 ADG 分流
迁移已通过。上游 sing-box 生成器保留全局 prefer_ipv6 行为，通过单独查询策略和
AAAA 规则实施 IPv4 策略；完整真实 shunt 的 A/AAAA 流量仍需目标验收。
apk 3.0.5 能读取 196 个本地安装记录，官方签名配置和仓库地址保留；离线缺少仓库
索引缓存的 warning 已记录。本次未证明在线安装或任意基础包升级成功。

早期缓存重建发现 APK 元数据和 readline 备份变化，三个核心二进制均未改变。
已修复 readline 并完成后续构建；本次可重复性证据仅是固定输入和重复归档后处理，
不宣称整个源码构建已在两个独立空缓存环境中逐字节一致。

## LXC 适配、迁移和仍待验证的功能

模板三套代理默认关闭，DHCP/RA 关闭，不固定占用现网 .2，不含 SSH 主机私钥、
ZeroTier 身份或预加入网络。LAN 初始 DHCP 客户端不接收默认路由和对端 DNS，
迁移前按说明设置测试地址。IPv4 forwarding 开、redirects 关、flow offload 关；
正常 GSO/GRO/checksum 保留，物理队列和 IRQ 不在 CT 写死。首次启动默认脚本排在
插件初始化之后，禁止它们重新自动启用代理。

OpenWrt 6.12.94 内核和真实 .ko 仅用于构建依赖，不是运行 PVE 内核。
不假造 kernel 包、uname 或强行依赖；自动 kmodloader 被抑制，加载/卸载入口拒绝，
不赋予 SYS_MODULE。只读 lsmod 保留，反映宿主内核；modinfo 在没有真实运行内核
对应目录时明确失败并提示去 PVE 宿主查询，不能冒用 OpenWrt .ko 作 PVE 证据。
sysntpd/sysfixtime 停用，由宿主管理时钟。dnsmasq/vlmcsd 的 procd jail 定点适配
有代码和静态证据，vlmcsd 服务用户保留；实际 CT 启动和降权运行尚未验证。

最小 CT 示例为非特权、ostype=unmanaged、默认 AppArmor、单 veth、2 CPU、1024 MiB、
swap 0、4 GiB rootfs、精确 tun 10:200 映射。目标只读预检查区分 built-in/module，
宿主准备仅按核验结果加载；编译机误用保护已检查。没有修改编译服务器的 PVE 网络，
没有修改现网 iKuai、OpenWrt VM、ADG、网桥或切换 .2。

目标仍需逐项执行：CT 启动和首次 defaults；SSH/HTTPS 和在线包管理；fw4/DNS/nftset
真实填充；TCP/UDP REDIRECT/TPROXY/socket 与策略路由的实际数据流；TUN/TAP；
三个代理插件逐个启停、DNS/防火墙/路由残留清理；HAProxy 真实节点切换；ZeroTier
TAP 和授权组网；隔离 KMS 监听及协议响应；双 ADG 未缓存查询、广告阻断、实际国内/
国外目的地、.4 源地址代理和独立 DNS 防递归。ct-function-test 规则安装即使通过，
也不等于真实代理负载通过。新 CT 使用 .250 而 .4 网关仍是旧 .2 时不能确认最终路径。

N100 性能需分别测同网段 2.5G 二层、经 CT 直连三层、代理 TCP/UDP、ZeroTier、
空闲/负载 CPU/RSS 和争用。flow offload 只提供限定直连 FORWARD 的 A/B；BBR 仅
用于本机终止 TCP 的实验。PVE 公共 LAN 网口归宿主管理，三个直通口归 iKuai，
CT 设置不作为物理卸载/RSS 生效证据。所有性能数值均待测。

完整操作见 [PVE 安装及双 ADG 迁移](pve-install.md)、
[目标功能验收](target-acceptance.md)、[性能测试](performance.md)。
[源码重建与升级](rebuild.md) 提供已执行的准备、下载、构建、后处理和验证命令；
升级脚本的当前稳定版检查已实际运行，新版本完整升级构建尚未执行。新基线改变
GCC/binutils 时必须更新工具链锁后审计。使用新模板测试 CT、备份和旧 CT 回滚，
不将 sysupgrade 当作已验证的 CT 升级路径；宿主内核升级后重复功能验收。
基础 apk 升级可能覆盖 loader/jail 适配，自定义 Xray 同名官方包可能丢失 SSR 补丁；
这些升级应通过维护分支重新构建和回归，不把同名包视为可直接替换。
