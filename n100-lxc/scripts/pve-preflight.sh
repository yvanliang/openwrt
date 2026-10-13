#!/bin/sh
# Read-only inventory. Run on the PVE HOST, not inside the OpenWrt VM/CT.
# No modules are loaded, no sysctls are changed, and no rules are installed.
# This does not replace functional nft/TPROXY/TAP tests inside the eventual CT.
set -eu

if ! command -v pveversion >/dev/null 2>&1; then
    printf '%s\n' 'Run this script on the Proxmox VE host.' >&2
    exit 2
fi

printf '\n%s\n' 'PVE and running kernel'
pveversion
uname -r

printf '\n%s\n' 'CPU model and relevant instruction flags'
awk -F ': ' '
    /^model name/ && !model++ { print $2 }
    /^flags/ && !flags++ {
        n=split($2,a," ")
        for (i=1;i<=n;i++)
            if (a[i] ~ /^(aes|pclmulqdq|avx|avx2|bmi1|bmi2|fma|sse4_1|sse4_2)$/)
                printf "%s ",a[i]
        print ""
    }
' /proc/cpuinfo

printf '\n%s\n' 'Selected kernel build options (y=built-in, m=module)'
audit_kernel_config="/boot/config-$(uname -r)"
if [ -r "$audit_kernel_config" ]; then
    awk '
        /^(# )?CONFIG_(NAMESPACES|USER_NS|NET_NS|VETH|BRIDGE|TUN|IP_MULTIPLE_TABLES|NF_TABLES|NF_TABLES_INET|NF_CONNTRACK|NF_NAT|NFT_NAT|NFT_REDIR|NFT_TPROXY|NFT_SOCKET|NF_TPROXY_IPV4|NF_SOCKET_IPV4|NFT_CT|NFT_COUNTER|NFT_FIB_INET|NFT_REJECT|INET_DIAG|INET_TCP_DIAG|RPS|RFS_ACCEL|XPS|NF_FLOW_TABLE|TCP_CONG_BBR)(=| )/ {print}
    ' "$audit_kernel_config"
else
    printf 'Kernel config not readable: %s\n' "$audit_kernel_config"
fi

printf '\n%s\n' 'Module file availability (absence alone does not exclude a built-in feature)'
for audit_module in veth bridge tun nf_tables nf_conntrack nf_nat nft_chain_nat nft_redir nft_tproxy nft_socket nf_tproxy_ipv4 nf_socket_ipv4 inet_diag tcp_diag tcp_bbr; do
    if command -v modinfo >/dev/null 2>&1; then
        if audit_module_path=$(modinfo -F filename "$audit_module" 2>/dev/null); then
            printf '%-20s %s\n' "$audit_module" "$audit_module_path"
        else
            printf '%-20s %s\n' "$audit_module" 'No module file found; check the kernel build option above.'
        fi
    fi
done

printf '\n%s\n' 'TUN device'
if [ -e /dev/net/tun ]; then
    ls -l /dev/net/tun
else
    printf '%s\n' '/dev/net/tun is absent; tun availability/loading must be resolved on the host.'
fi

printf '\n%s\n' 'Current PVE support for explicit CT device mapping'
if command -v pct >/dev/null 2>&1; then
    pct help set 2>&1 | awk '/dev\[|dev[0-9]|device passthrough|Device passthrough/ {print}'
fi

printf '\n%s\n' 'Physical interfaces visible to PVE (passed-through iKuai NICs are controlled by iKuai)'
for audit_link in /sys/class/net/*; do
    [ -e "$audit_link/device" ] || continue
    audit_ifname=${audit_link##*/}
    printf '\nInterface: %s\n' "$audit_ifname"
    if command -v ethtool >/dev/null 2>&1; then
        ethtool "$audit_ifname" 2>/dev/null | awk '/Speed:|Duplex:|Link detected:/ {print}'
        ethtool -i "$audit_ifname" 2>/dev/null | awk '/^driver:|^version:|^firmware-version:/ {print}'
        ethtool -l "$audit_ifname" 2>/dev/null || :
    fi
done

printf '\n%s\n' 'Inventory complete. No host or guest configuration was changed.'
