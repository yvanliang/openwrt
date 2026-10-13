#!/bin/bash
# PRoot version/config checks; local Unix IPC, no network listeners.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
OUT=${1:?release directory required}
CHECK="$PROJECT_ROOT/work/userspace-check-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$CHECK"
printf '%s\n' "$CHECK" > "$PROJECT_ROOT/work/last-userspace-root.txt"
tar --no-same-owner -xzf "$OUT/rootfs.tar.gz" -C "$CHECK"
mkdir -p "$CHECK/tmp" "$CHECK/proc" "$CHECK/dev" "$CHECK/tmp/checks"
python3 - "$CHECK" "$OUT" <<'PY'
# SO_PEERCRED reports the real host UID in PRoot. Prepare only the test copy.
import json,os,pathlib,sys
root=pathlib.Path(sys.argv[1]);uid=os.getuid();gid=os.getgid()
passwd=root/'etc/passwd';group=root/'etc/group'
users=[line.split(':') for line in passwd.read_text().splitlines()]
groups=[line.split(':') for line in group.read_text().splitlines()]
user=next((x[0] for x in users if x[2]==str(uid)),'n100-userspace-check')
if not any(x[2]==str(uid) for x in users):
 with passwd.open('a') as f:f.write(f'{user}:x:{uid}:{gid}:Offline config test:/tmp:/bin/false\n')
if not any(x[2]==str(gid) for x in groups):
 with group.open('a') as f:f.write(f'n100-userspace-check:x:{gid}:\n')
acl={'user':user,'access':{'*':{'methods':['*']}},'publish':['*'],'subscribe':['*'],'send':['*'],'listen':['*']}
acl_path=root/'usr/share/acl.d/n100-offline-test.json'
acl_path.write_text(json.dumps(acl)+'\n');acl_path.chmod(0o644)
report={'host_uid':uid,'host_gid':gid,'unix_ipc_test_user':user,
 'scope':'Test extraction only: passwd/group peer mapping and local ubus ACL. No CT/PVE boot or production authorization validation.'}
pathlib.Path(sys.argv[2]+'/userspace-test-adjustments.json').write_text(json.dumps(report,indent=2)+'\n')
example="""mixed-port: 7893
allow-lan: false
bind-address: 127.0.0.1
mode: rule
log-level: info
ipv6: false
geodata-mode: true
geodata-loader: standard
geox-url: {}
geo-auto-update: false
dns:
  enable: true
  listen: 127.0.0.1:7874
  ipv6: false
  enhanced-mode: redir-host
  nameserver: [223.5.5.5]
"""
(root/'tmp/checks/mihomo-direct.yaml').write_text(example+'rules:\n  - MATCH,DIRECT\n')
for mode,label in [('true','dat'),('false','mmdb')]:
 text=example.replace('geodata-mode: true','geodata-mode: '+mode)
 text+='rules:\n  - GEOSITE,cn,DIRECT\n  - GEOIP,CN,DIRECT\n  - MATCH,DIRECT\n'
 (root/f'tmp/checks/clash-geodata-{label}.yaml').write_text(text)
PY
cp "$BASE/tests/core-configs.lua" "$CHECK/tmp/checks/core-configs.lua"
cp "$BASE/tests/check-defaults.sh" "$CHECK/tmp/checks/check-defaults.sh"
cp "$BASE/tests/generator-check.sh" "$CHECK/tmp/checks/generator-check.sh"
cp "$BASE/tests/passwall-nofile.sh" "$CHECK/tmp/checks/passwall-nofile.sh"
cat > "$CHECK/tmp/checks/xray-direct.json" <<'EOF'
{"log":{"loglevel":"warning"},"inbounds":[{"listen":"127.0.0.1","port":19080,"protocol":"socks","settings":{"udp":true}}],"outbounds":[{"protocol":"freedom"}]}
EOF
cat > "$CHECK/tmp/checks/sing-box-direct.json" <<'EOF'
{"log":{"level":"warn"},"inbounds":[{"type":"mixed","listen":"127.0.0.1","listen_port":19081}],"outbounds":[{"type":"direct","tag":"direct"}]}
EOF
run() { proot -0 -r "$CHECK" -b /proc -b /dev -w / /bin/sh -ec "export PATH=/usr/sbin:/usr/bin:/sbin:/bin TMPDIR=/tmp; $1"; }
{
 echo 'Environment: PRoot path virtualization on build-server kernel; no CT boot/network isolation or target acceptance.'
 echo 'Test extraction maps the real SO_PEERCRED UID/GID and grants local ubus ACL for offline RPC; see userspace-test-adjustments.json.'
 uname -a
 run 'xray version; sing-box version; /etc/openclash/core/clash_meta -v; zerotier-one -v; dnsmasq --version; ruby -v; haproxy -vv'
 run 'apk --version; echo "Installed package records:"; apk info | wc -l'
 run 'echo "Read-only module query on build-server kernel:"; lsmod | head -3; kernel=$(uname -r); if [ ! -d "/lib/modules/$kernel" ]; then status=0; modinfo nft_socket || status=$?; test "$status" = 1; echo "EXPECTED: running-kernel metadata absent in template; modinfo delegates diagnosis to host."; else echo "Running-kernel metadata is present; target module queries require host validation."; fi'
 run 'ruby -ryaml -e '\''p YAML.load_file("/tmp/checks/mihomo-direct.yaml")["mode"]'\'''
 run 'xray run -test -config /tmp/checks/xray-direct.json'
 run 'sing-box check -c /tmp/checks/sing-box-direct.json'
 run '/etc/openclash/core/clash_meta -t -d /etc/openclash -f /tmp/checks/mihomo-direct.yaml'
 run '/etc/openclash/core/clash_meta -t -d /etc/openclash -f /tmp/checks/clash-geodata-dat.yaml'
 run '/etc/openclash/core/clash_meta -t -d /etc/openclash -f /tmp/checks/clash-geodata-mmdb.yaml'
 run 'mkdir -p /var/etc/passwall2 /tmp/etc/passwall2 /tmp/etc/passwall2_tmp /tmp/.uci; cp /usr/share/passwall2/0_default_config /etc/config/passwall2; cp /usr/share/shadowsocksr/shadowsocksr.config /etc/config/shadowsocksr; uci set passwall2.@global[0].enabled=0; uci set passwall2.@global_app[0].xray_file=/usr/bin/xray; uci commit passwall2'
 run 'sh /tmp/checks/check-defaults.sh; /usr/sbin/lxc-adaptation-check'
 run 'sh /tmp/checks/passwall-nofile.sh'
 run 'sh /tmp/checks/generator-check.sh'
 run 'ruby -ryaml -e '\''p YAML.load_file("/tmp/checks/mihomo-direct.yaml")'\'''
 echo 'PASS: userspace version and generated configuration checks. Network/service behavior remains untested.'
} 2>&1 | tee "$OUT/userspace-verification.log"
cp -a "$CHECK/tmp/checks" "$OUT/generated-test-configs"
