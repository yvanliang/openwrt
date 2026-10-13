# 性能选项与目标验收

| 项目 | 模板决定 | 适用层与证据/待测内容 |
|---|---|---|
| x86 指令基线 | x86-64、GOAMD64=v1；不使用 march=native | N100 通用兼容；服务器 Xeon 指令不能用作 N100 证据 |
| AES-NI/PCLMUL | 保留核心运行时指令检测和汇编加速路径 | Go crypto/核心会在实际 CPU 上检测；N100 指令与收益需目标测试 |
| nftset | dnsmasq-full nftset 编译开启 | CT DNS 分流；版本输出与隔离/目标 nftset 填充分别验证 |
| TCP/UDP socket/TPROXY | 保留依赖和用户态实现 | PVE 宿主提供内核功能；规则创建不等于真实负载通过 |
| 策略路由/TUN/TAP | ip-full、tun、inet_diag/netlink_diag 依赖保留 | CT 网络命名空间和精确 /dev/net/tun 映射需目标验收 |
| flow offload | 默认软件和硬件均关闭 | FORWARD 可获益，但代理加解密不能被 offload；分流交互需限定直连 A/B 测试 |
| GRO/GSO/TSO/checksum | 保持正常默认；不统一关闭 | 宿主物理口、bridge、veth 分层测量；仅在重传/校验问题有证据时调整 |
| RSS/RPS/XPS/IRQ | 不在模板写死 CPU 亲和性 | PVE 仅管理公共 LAN 物理口；三个直通口由 iKuai 管理 |
| CPU/内存 | 初始 2 核、1024 MiB、无 swap | N100 4 核需与 iKuai、ADG 争用实测；三个核心同时常驻会浪费资源 |
| UPX | 移除 Xray/Mihomo 的压缩后处理 | 保留所有协议补丁，降低启动解压与内存开销；不为省空间影响审计 |
| Ruby YJIT | 关闭；保留 Ruby/YAML | 用于管理配置解析，不在代理数据路径上；避免无收益的 JIT 和 Rust 构建依赖 |
| BBR | 默认不设置 | 仅实验本机终止的 TCP 代理；不声称改善纯转发、UDP、QUIC 或 ZeroTier |
| IPv4 forwarding/redirects | forwarding=1，send/accept redirects=0 | 单口网关语义；不改变双 ADG 路径 |
| NSS/SFE/硬件 NAT | 不引入 | N100/PVE 没有由本项目证明的此类加速路径 |
| nesting/keyctl | 不启用 | 权限功能，不是性能开关 |

在 N100 上记录 PVE 内核、CPU flags（含 aes、pclmulqdq）、CT 配额、代理协议、
节点延迟与服务器能力、链路、iperf3 版本、重传、CPU 每核占用和内存。
`GOAMD64=v3` 需要完整 v3 指令清单，包括 AVX/AVX2/FMA/BMI1/BMI2/F16C/ABM/MOVBE
及 OSXSAVE 状态，并测得收益后才考虑单独实验构建；当前不默认使用。

分别执行五组测试，每组正反向和并行度 1/4，至少三次：

1. 同网段 2.5G 二层：两台 2.5G 终端直接 iperf3，记录链路；通常不经过 CT 三层。
2. 经 CT 直连三层：隔离源/目的网段，确认 ip route、nft counters 和 traceroute 确实经过 CT。
3. 代理 TCP/UDP：节点具有足够上游容量，记录真实出口 IP、协议、核心与加密；不要借公网节点瓶颈推断 N100 上限。
4. ZeroTier：授权网络、直接/中继路径分别记录，测试 TAP 与 underlay 路径。
5. 空闲/满载：CT/PVE/iKuai/ADG CPU、RSS 内存、队列丢包和温度/降频。

基本命令：`iperf3 -c TEST_SERVER -t 60 -P 1`，`-R`，`-P 4`，
UDP 从合理速率逐级上升，例如 `-u -b 500M`。所有地址都是隔离测试端点，不能
仅凭命令示例判定达到千兆代理或 2.5G。当前目标 PVE/N100 吞吐结果均待验收。

软件 flow offload A/B 仅在没有透明代理命中的直连 FORWARD 路径做：保存 UCI，
设置 firewall.@defaults[0].flow_offloading=1，reload，确认 nft flowtable 与实际命中，
比较吞吐/CPU/重传/DNS/策略路由。异常时恢复原配置并 reload。不要宣称它必然与所有代理冲突。
BBR A/B 先在 PVE 核验 CONFIG_TCP_CONG_BBR、加载模块，再在测试 CT 核验可用拥塞算法，
只改变该 CT 的 TCP 算法并保留 cubic 回滚。物理口卸载/RSS 的变更必须在 PVE 做，
涉及 iKuai 直通口的变更另由用户在 iKuai 验证。
