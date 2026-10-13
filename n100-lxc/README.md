# OpenWrt N100 / PVE LXC

维护分支：`n100-pve-lxc/25.12.5`，基于官方 `v25.12.5`。
所有工程文件位于 `/data/disk2/lyy_dataset/openwrt/`。

入口：

- [源码重建与上游升级](docs/rebuild.md)
- [PVE 安装、双 ADG 迁移与回滚](docs/pve-install.md)
- [性能选项及测量方法](docs/performance.md)
- [目标功能验收步骤](docs/target-acceptance.md)
- [本次编译与验证报告](docs/validation-report.md)

`config/` 保存种子、最终配置和配置审计；`locks/` 固定仓库、提供方、
宿主依赖和规则数据。完整构建后生成 `source-lock.json` 和模板验证报告。
`package/n100-lxc/` 保存第三方配方，`toolchain/golang/` 保存固定 Go 配方。
`baseline/` 保留收到的原始研究资料，其未完成标注不代表构建配置。

模板预装三套代理管理插件，默认均关闭，初始不占用现网 `.2`。
ZeroTier 包含中文管理入口“服务 → ZeroTier”，未配置时保持关闭。
Passwall2 启动只调整文件句柄软上限，保留宿主提供的硬上限；补丁在源码准备时自动检查应用。
OpenClash 从 procd 的 `/proc/1/limits` 读取硬上限，仅设置不超过 65535 的软上限；
不请求提高其他资源限制。缺失的自动重启/路由更新选项初始化为 0，已有值保持不变。
模板不预置可选的个人或示例代理配置，离线检查配置仅在临时测试目录生成。
PVE 宿主提供运行内核；OpenWrt `.ko` 不加载到宿主。
执行构建和归档检查不代表 PVE/N100 验收。用户已暂停 QEMU 测试。
