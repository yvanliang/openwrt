# 目标验收记录表

本表是可执行的验收方法，空白项不代表通过。用户已要求暂停 QEMU 测试。
PRoot 核心版本/配置检查不具有网络隔离，也不证明 CT 启动或 PVE 内核功能。

| 状态层次 | 证据要求 |
|---|---|
| 成功编译 | make 完成，rootfs/manifest/.config/source-lock |
| 静态/用户态通过 | 归档检查 JSON、核心版本和实际插件生成配置校验日志 |
| 隔离功能通过 | 明确内核、环境、CT 类型和实际流量；当前 QEMU 暂停 |
| PVE 7.0.14-8-pve 通过 | 运行内核实际预检查、默认 AppArmor 非特权 CT 功能日志 |
| N100 吞吐通过 | performance.md 五组测量及完整链路说明 |

1. **宿主**：运行 pve-preflight，保留 pveversion、uname、config/modinfo、设备和 CPU flags。
   宿主按需准备后，在测试 CT 运行 `ct-function-test --disposable-ct`。它只证明规则、
   路由、TUN/TAP 创建；不能替代真实 TCP/UDP 转发。
2. **冷启动**：启动测试 CT，检查 /proc/1/comm=procd、ubus system board、boot/logread，
   连续重启两次，确认无不匹配模块、sysntpd、dnsmasq jail 或 vlmcsd jail 故障循环。
   通过 console 设置密码后测试 SSH 和 HTTPS，确认 apk 能读取签名仓库索引和安装诊断包。
3. **DNS/nftset**：使用测试 DNS 上游，建立临时 nft set。dnsmasq-full 用
   `--nftset=/test.example/4#inet#TEST_TABLE#TEST_SET` 接收真实未缓存 A 查询，
   `dig @CT_IP random.test.example A` 和 `+tcp` 均返回，nft set 出现预期地址。
   删除临时表、恢复 DNS。验证 DNS 重启后再次填充。不要依赖此前缓存。
4. **TCP/UDP 透明代理**：在隔离源/目的网段使用本地授权代理服务器，分别验证 Xray、
   sing-box/Mihomo 对 REDIRECT/TPROXY 的真实转发，抓包确认目的地和 nft counters，
   UDP 使用持续双向流量。只成功添加 nft tproxy 规则不能标记此项通过。
5. **三个插件**：分别保存干净的 nft、ip rule、全表路由和 DNS 片段快照。导入真实
   测试节点，启用一套，验证生成配置、进程、透明 TCP/UDP、DNS和 HAProxy（PW2），
   然后 stop-all 对比残留。SSR 特有 AnyTLS/allowInsecure 行为与实际现网节点
   单列。再验证另一套。OpenClash 应在断开外部下载条件下直接使用预置 clash_meta
   和规则数据启动；规则提供方在线 URL 若需要，另记录输入版本。
6. **ZeroTier**：模板不存在 identity 和预加入网络。启用后检查服务状态；先验证
   `ip tuntap add dev n100tap mode tap` 再删除。只有拥有授权 network ID 才加入网络，
   记录 zerotier-cli info/listnetworks、TAP、direct/relay 对端和 underlay 路由。
   没有授权 ID 时不能伪造组网结果。
7. **KMS**：只在隔离网络启用 vlmcsd，确认 UID 为 vlmcsd、TCP 1688 监听范围，
   用测试 vlmcs 客户端发送一次协议请求并记录响应。不得开放互联网端口。
8. **双 ADG**：分别从普通终端查询新的国内/国外测试域名，抓 CT、.3、.4 三处包，
   记录去广告结果和真实上游目的地；确认 LAN 到 .3/.4 的 DNS 直达。以 .4 为源的
   普通外联应经代理，它的系统 DNS 223.5.5.5 应经独立 bootstrap/防劫持路径。
   检查无重复递归请求、TTL 循环和异常 DNS 目标。测试 IP CT 不能证明 .4 仍走旧 .2
   时的最终路由。割接 .2 后才验证最终往返。
9. **性能和回滚**：依照 performance.md 区分二层、直连三层、代理、ZeroTier与资源
   测量；按 pve-install.md 备份并演练停止新 CT/恢复旧 VM .2，记录回滚后 DNS。

建议每项记录 `时间 / 运行内核 / CPU / CT 类型与配额 / 命令与日志 / 结果 / 限制`。
PVE 内核升级后，以上宿主、启动、透明代理和 TUN/TAP 相关测试必须重新执行。

OpenClash 资源限制修复的目标验收需另行安排：在非特权测试 CT 中记录
`/proc/1/limits`、procd 服务实例和 Mihomo 进程的 nofile 软/硬上限；通过
`/etc/init.d/openclash start` 和 `restart` 启动，确认核心存活、API/DNS 可用，
日志没有资源限制权限错误。仅在 SSH shell 启动核心不算 procd 验收。
本轮用户明确不执行测试，上述项目保持未验收，不修改生产订阅、DNS 或策略组。
