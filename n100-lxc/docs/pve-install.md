# PVE 导入、迁移和宿主准备

这里的 PVE 命令尚未在用户的 PVE/N100 上执行。目标内核由用户提供为
`7.0.14-8-pve`；模板不提供该内核的模块。编译或隔离服务器结果不代表目标验收。

## 宿主和 CT 的分工

CT 管理 fw4/nft 规则、dnsmasq nftset、策略路由、IPv4 forwarding 和代理服务。
PVE 提供 veth/bridge、网络与用户命名空间、conntrack/NAT/REDIRECT、socket/TPROXY、
TUN/TAP、inet_diag/netlink_diag。CT 中的 OpenWrt `.ko` 仅保留包依赖一致性，
`kmodloader` 已替换成容器适配脚本，不会把这些模块载入 PVE。
lsmod 只读查询使用同一次源码构建的 ubox 程序，显示运行宿主内核的模块列表。
ubox 的 modinfo 按真实 uname 查找对应模块目录；模板没有 PVE 模块元数据，
此时返回明确提示和失败状态，要求在 PVE 宿主查询，不能用 OpenWrt 的 6.12 模块
代替它。原查询程序保留；CT 中看到的模块列表不能替代宿主配置和实际功能验收。
不要添加 SYS_MODULE、伪造 uname、使用 force-depends 或假 kernel 包。

HAProxy 核心保留，独立 init 服务的上游示例配置不自动启动；PW2 在开启负载均衡后
生成自己的临时配置并启动 HAProxy，不依赖该示例服务。实际节点负载均衡仍需目标测试。

在 PVE 上先运行 `scripts/pve-preflight.sh`，保存完整输出。核对正在运行的内核的
`/boot/config-$(uname -r)`，`y` 是内置，`m` 需要宿主模块，不能只看 lsmod。
再审阅并按需运行 `scripts/pve-host-prepare.sh --apply-reviewed-modules`。
不要在编译服务器运行宿主准备。仅将确实加载成功且目标需要的模块名写入
`/etc/modules-load.d/openwrt-lxc.conf`，例如 nft_tproxy、nft_socket、tun；内置能力
不需要写入。如 config 为 unset 且功能测试失败，保存 config、modinfo 与 nft 错误，
检查官方 PVE 内核包/支持渠道。此流程不编译或替换 PVE 内核。

## 创建隔离测试 CT

先上传 rootfs.tar.gz 到用户选择的 PVE 模板存储。
示例中的 CTID、storage 和 vmbr0 都需要按宿主现有配置替换。不要改现网网桥。

```sh
pct create 120 local:vztmpl/rootfs.tar.gz --ostype unmanaged --unprivileged 1 \
  --cores 2 --memory 1024 --swap 0 --rootfs local-lvm:4 \
  --net0 name=eth0,bridge=vmbr0,firewall=1,type=veth --onboot 0
pct start 120
```

模板的 eth0 为 DHCP 客户端，关闭默认路由和 peerdns，用于获取不冲突的管理地址；
DHCP/RA 服务端均关闭。首次使用 `pct console 120` 或 `pct exec 120 -- ...` 管理，
设置 root 密码后再使用 SSH 和 HTTPS。示例测试 IP 192.168.0.250 必须确认未占用：

```sh
pct exec 120 -- uci set network.lan.proto=static
pct exec 120 -- uci set network.lan.ipaddr=192.168.0.250
pct exec 120 -- uci set network.lan.netmask=255.255.255.0
pct exec 120 -- uci set network.lan.gateway=192.168.0.1
pct exec 120 -- uci set network.lan.defaultroute=1
pct exec 120 -- uci add_list network.lan.dns=223.5.5.5
pct exec 120 -- uci commit network
pct exec 120 -- /etc/init.d/network restart
pct exec 120 -- passwd
```

使用当前 PVE 支持的精确设备映射（以 `pct help set` 输出为准）：

```sh
pct set 120 --dev0 path=/dev/net/tun
```

若当前 PVE 不支持 dev0，最小旧式映射如下；不要同时重复配置两种映射：

```text
ostype: unmanaged
unprivileged: 1
cores: 2
memory: 1024
swap: 0
net0: name=eth0,bridge=vmbr0,firewall=1,type=veth
rootfs: local-lvm:vm-120-disk-0,size=4G
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

保持默认 AppArmor。不默认启用 nesting/keyctl，不默认特权 CT、unconfined 或开放所有设备。
遇到拒绝时保存 `journalctl -k` 中对应 CT 的 AppArmor/cgroup 证据，然后调整最小权限。
dnsmasq 和 vlmcsd 的内部 procd jail 根据 LXC 官方镜像做定点禁用，宿主 LXC 隔离仍保留；
vlmcsd 专用用户和组仍保留。sysntpd/sysfixtime 禁用，时间由 PVE 提供。

PVE 外层防火墙的源 IP/MAC 反欺骗过滤可能阻断源地址为普通终端的转发包。
若启用外层防火墙，明确允许被此 CT 转发的源网段，并实测；不要把所有 CT 的防火墙关闭。

## 业务配置迁移

保存旧 OpenWrt VM 的 UCI、节点和订阅配置，在私有位置操作，不能提交到 GitHub。
模板不包含现网三个候选节点。先运行 `proxy-manager status` 保存干净快照。
仅启用 Passwall2；SSR Plus+ 和 OpenClash 保持关闭。

国内 DNS 指向 192.168.0.3，国外 DNS 指向 192.168.0.4。二者在 eth0 的同一 LAN
上，必须保留直达路径，不给本地 .3/.4 DNS 流量套代理。国外 ADG 的外联按源 .4
走代理；它自身 DNS/bootstrap 走独立路径，不能再被全局 DNS 捕获并送回 .4。
全局 FakeDNS 和 IPv6 代理保持关闭，单网口 send/accept redirects 为 0。
设置远端 DNS 为 LAN 内 .4 时，PW2 的 remote_dns_detour 应为 direct；否则生成器
可能将该 DNS 请求发给代理节点。已经用真实生成器检查此字段的配置路径，尚未实测网络。
sing-box 生成器按域名规则处理 UseIPv4，保留全局 prefer_ipv6 以免一条路径的策略覆盖另一条；
迁移后必须用真实国内/国外 A/AAAA 查询检查规则效果，不能仅凭一个全局字段判定。
迁移后检查 `ip route get 192.168.0.3`、`ip route get 192.168.0.4`、抓包和实际规则。
在 .4 仍以旧 .2 为网关期间，新 .250 CT 只能做局部测试，不能验证最终 .4 出站路径。

切换管理程序前运行 `proxy-manager stop-all`，对照干净快照检查 DNS 片段、nft
表/链、ip rule 和路由。存在未解释残留时重启测试 CT 并重新核对，不能盲目删除
整个系统策略路由。验证配置后使用：

```sh
proxy-manager start passwall2 --configuration-validated
# 或 shadowsocksr / openclash，任一时刻只运行一套。
```

分别配置真实测试节点和本地回环节点，验证每套程序的 TCP/UDP、DNS 与停止清理。
SSR 专用补丁仍在共享 Xray 中；生成配置测试及现网节点兼容性必须分别记录。
未授权 ZeroTier 网络时只测试服务和 TAP，不假称已组网。未配置模板没有 ZeroTier 身份。
KMS 默认关闭；只在隔离测试网络中启用，验证监听和协议响应，不开放互联网入口。

## 割接与回滚

先对旧 VM、两台 ADG 和 CT 做用户控制的备份，保留旧模板、锁文件和配置。
通过目标验收后再安排维护窗口：关闭旧 .2 接口，确认地址释放，再给新 CT 配置 .2，
保持 iKuai 网关/DHCP 和 .3/.4 地址不变。抓包验证 .4 的真实回程和 DNS 防回环。
回滚时停止新 CT，恢复旧 VM 的 .2，再核验两台 ADG。不要让两台实例同时持有 .2。
OpenWrt 磁盘固件 sysupgrade 不是已验证的 CT 升级方法；用新模板建测试 CT，
验证后迁移配置并替换。PVE 内核升级后重新执行宿主与 CT 功能验收。
