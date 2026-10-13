#!/bin/sh
# Exercise only UCI assignments. Do not invoke init scripts in PRoot.
set -eu
sed '/^for s in/,$d' /etc/uci-defaults/zzzz-n100-lxc > /tmp/checks/n100-uci.sh
sh /tmp/checks/n100-uci.sh
while IFS='=' read -r key expected; do
 actual=$(uci -q get "$key")
 [ "$actual" = "$expected" ] || { echo "FAIL: $key=$actual expected $expected"; exit 1; }
 echo "PASS: $key=$actual"
done <<'EOF'
passwall2.@global[0].enabled=0
passwall2.@global[0].fake_dns=0
passwall2.@global[0].ipv6_proxy=0
passwall2.@global[0].direct_dns_query_strategy=UseIPv4
passwall2.@global[0].remote_dns_query_strategy=UseIPv4
passwall2.@global_app[0].xray_file=/usr/bin/xray
shadowsocksr.@global[0].global_server=nil
shadowsocksr.@global[0].enable=0
openclash.config.enable=0
openclash.config.auto_restart=0
openclash.config.chnr_auto_update=0
openclash.config.core_version=linux-amd64-v1
openclash.config.disable_quic_go_gso=0
openclash.config.en_mode=redir-host
openclash.config.ipv6_enable=0
zerotier.global.enabled=0
vlmcsd.config.enabled=0
EOF
