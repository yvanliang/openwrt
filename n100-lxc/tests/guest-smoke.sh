#!/bin/sh
# Executed only in the QEMU guest with no physical or host LAN attachment.
set -u
mkdir -p /tmp/n100-test
printf 'mode: rule\nrules:\n  - MATCH,DIRECT\n' > /tmp/n100-test/mihomo-direct.yaml
exec > /dev/console 2>&1
echo 'N100_ISOLATED_TEST_BEGIN'
uname -a
cat /proc/1/comm
failures=0
run() {
 label=$1; shift
 echo "TEST_BEGIN:$label"
 if "$@"; then echo "TEST_PASS:$label"; else failures=$((failures+1)); echo "TEST_FAIL:$label"; fi
}
run core_versions sh -c 'xray version; sing-box version; /etc/openclash/core/clash_meta -v; zerotier-one -v; dnsmasq --version'
run yaml ruby -ryaml -e 'puts YAML.load_file("/tmp/n100-test/mihomo-direct.yaml")["mode"]'
run mihomo_config /etc/openclash/core/clash_meta -t -d /etc/openclash -f /tmp/n100-test/mihomo-direct.yaml
run fw4 /sbin/fw4 check
run ct_functions /usr/sbin/ct-function-test --disposable-ct
run https sh -c 'curl -ksS https://127.0.0.1/ | head -c 160'
run ssh sh -c 'netstat -lnt | grep ":22 "'
run proxy_managers_disabled sh -c '! ps w | grep -E "[x]ray run|[s]ing-box run|/etc/openclash/[c]lash"'
dnsmasq --keep-in-foreground --port=1553 --conf-file=/dev/null --no-resolv \
 --listen-address=127.0.0.1 --bind-interfaces --address=/n100.test/198.18.1.2 \
 --pid-file=/tmp/n100-test/upstream.pid > /tmp/n100-test/upstream.log 2>&1 &
upstream=$!
uci -q delete dhcp.@dnsmasq[0].server
uci add_list 'dhcp.@dnsmasq[0].server=127.0.0.1#1553'
uci commit dhcp
/etc/init.d/dnsmasq restart
sleep 3
run dns_udp dig @127.0.0.1 fresh.n100.test A +short
run dns_tcp dig @127.0.0.1 fresh-tcp.n100.test A +tcp +short
run dnsmasq_restart sh -c '/etc/init.d/dnsmasq restart; sleep 3; dig @127.0.0.1 another.n100.test A +short | grep 198.18.1.2'
run nftset sh -c '
 nft add table inet n100_dns
 nft add set inet n100_dns learned "{ type ipv4_addr; }"
 dnsmasq --keep-in-foreground --port=1554 --conf-file=/dev/null --no-resolv --bind-interfaces --listen-address=127.0.0.1 --server=127.0.0.1#1553 --nftset=/n100.test/4#inet#n100_dns#learned --pid-file=/tmp/n100-test/nftdns.pid > /tmp/n100-test/nftdns.log 2>&1 &
 pid=$!
 sleep 2
 dig @127.0.0.1 -p 1554 nftset.n100.test A +short
 nft list set inet n100_dns learned | grep 198.18.1.2
 status=$?
 kill "$pid"
 nft delete table inet n100_dns
 exit "$status"
'
for service in passwall2 shadowsocksr openclash; do
 run "disabled_start_stop_$service" sh -c "/etc/init.d/$service start; sleep 2; /etc/init.d/$service stop"
done
run policy_cleanup sh -c '! ip -4 rule show | grep -E "lookup (100|140|354)"'
kill "$upstream" 2>/dev/null || true
echo "N100_ISOLATED_TEST_END failures=$failures"
sync
poweroff -f
