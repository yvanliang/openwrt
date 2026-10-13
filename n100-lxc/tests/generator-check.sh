#!/bin/sh
# Project-local Unix IPC only; no procd, init services or proxy listeners.
set -eu
export PATH=/usr/sbin:/usr/bin:/sbin:/bin TMPDIR=/tmp
mkdir -p /var/run/ubus
/sbin/ubusd -s /var/run/ubus/ubus.sock > /tmp/checks/ubusd.log 2>&1 &
ubus_pid=$!
rpcd_pid=''
cleanup() {
 [ -z "$rpcd_pid" ] || kill "$rpcd_pid" 2>/dev/null || true
 kill "$ubus_pid" 2>/dev/null || true
 wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM
attempt=0
while [ ! -S /var/run/ubus/ubus.sock ]; do
 attempt=$((attempt+1));[ "$attempt" -lt 15 ] || exit 1;sleep 1
done
/sbin/rpcd -s /var/run/ubus/ubus.sock -t 30 > /tmp/checks/rpcd.log 2>&1 &
rpcd_pid=$!
attempt=0
while ! ubus list uci 2>/dev/null | grep -q '^uci$'; do
 attempt=$((attempt+1));[ "$attempt" -lt 15 ] || { cat /tmp/checks/rpcd.log;exit 1; };sleep 1
done
lua /tmp/checks/core-configs.lua
xray run -test -config /tmp/checks/pw2-xray.json
sing-box check -c /tmp/checks/pw2-sing-box.json
lua /usr/share/shadowsocksr/gen_config.lua n100test tcp 19082 19083 > /tmp/checks/ssr-xray.json
xray run -test -config /tmp/checks/ssr-xray.json
uci set shadowsocksr.n100test.v2ray_protocol=anytls
uci set shadowsocksr.n100test.tls=1
uci set shadowsocksr.n100test.insecure=1
uci set shadowsocksr.n100test.password=synthetic-local-test
uci commit shadowsocksr
lua /usr/share/shadowsocksr/gen_config.lua n100test tcp 19082 19083 > /tmp/checks/ssr-anytls.json
xray run -test -config /tmp/checks/ssr-anytls.json
