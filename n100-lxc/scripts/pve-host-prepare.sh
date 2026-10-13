#!/bin/sh
# Run as root on PVE only, after reviewing pve-preflight output.
set -eu
[ "${1:-}" = '--apply-reviewed-modules' ] || { echo 'Run preflight, review, then use --apply-reviewed-modules'; exit 2; }
command -v pveversion >/dev/null
kernel=$(uname -r)
echo "Preparing the running PVE kernel: $kernel"
case "$kernel" in *-pve) ;; *) exit 2 ;; esac
config=/boot/config-$kernel
[ -r "$config" ] || { echo 'Kernel config required to distinguish built-ins'; exit 2; }
for pair in 'VETH:veth' 'BRIDGE:bridge' 'TUN:tun' 'NF_TABLES:nf_tables' \
 'NF_CONNTRACK:nf_conntrack' 'NF_NAT:nf_nat' 'NFT_NAT:nft_chain_nat' \
 'NFT_REDIR:nft_redir' 'NFT_TPROXY:nft_tproxy' 'NFT_SOCKET:nft_socket' \
 'NF_TPROXY_IPV4:nf_tproxy_ipv4' 'NF_SOCKET_IPV4:nf_socket_ipv4' \
 'NFT_CT:nft_ct' 'NFT_COUNTER:nft_counter' 'NFT_FIB_INET:nft_fib_inet' \
 'NFT_REJECT_INET:nft_reject_inet' 'INET_DIAG:inet_diag' 'INET_TCP_DIAG:tcp_diag' \
 'NETLINK_DIAG:netlink_diag'; do
 symbol=${pair%:*}; module=${pair#*:}
 if grep -qx "CONFIG_$symbol=y" "$config"; then
  echo "$symbol built in"
 elif grep -qx "CONFIG_$symbol=m" "$config"; then
  modprobe "$module"
  echo "$module"
 else
  echo "Missing CONFIG_$symbol; inspect the PVE kernel package before proceeding" >&2
  exit 1
 fi
done
echo 'Modules loaded for this running kernel. Review before persistence; see docs/pve-install.md.'
