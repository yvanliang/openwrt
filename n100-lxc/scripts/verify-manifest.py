#!/usr/bin/python3
import argparse,json,pathlib
p=argparse.ArgumentParser();p.add_argument('manifest');p.add_argument('--report',required=True);args=p.parse_args()
packages={}
for line in pathlib.Path(args.manifest).read_text().splitlines():
 if ' - ' in line:
  name,version=line.split(' - ',1);packages[name]=version
required=['apk-mbedtls','dropbear','uhttpd','uhttpd-mod-ubus','luci-i18n-base-zh-cn',
 'firewall4','nftables-json','dnsmasq-full','ip-full','luci-app-passwall2','sing-box',
 'xray-core','haproxy','luci-app-ssr-plus','shadowsocksr-libev-ssr-local',
 'shadowsocksr-libev-ssr-redir','luci-app-openclash','mihomo','ruby-yaml','zerotier','luci-app-zerotier','luci-i18n-zerotier-zh-cn','vlmcsd']
expected={'luci-app-passwall2':'26.10.1-r3','luci-app-ssr-plus':'196-r19',
 'luci-app-openclash':'0.48.002-r1','xray-core':'26.9.30-r5','sing-box':'1.14.3-r1','mihomo':'1.19.32-r2'}
missing=[name for name in required if name not in packages]
wrong={name:{'actual':packages.get(name),'expected_prefix':version} for name,version in expected.items()
 if not packages.get(name,'').startswith(version)}
unwanted=[name for name in packages if name in ['dnsmasq','ppp','ppp-mod-pppoe','odhcp6c',
 'odhcpd-ipv6only','docker','dockerd','samba4-server','grub2','kmod-igb','kmod-igc','kmod-drm-i915']]
report={'package_count':len(packages),'packages':packages,'missing_required':missing,
 'unexpected_versions':wrong,'unwanted_packages':unwanted,'all_passed':not(missing or wrong or unwanted)}
pathlib.Path(args.report).write_text(json.dumps(report,indent=2)+'\n')
print('Manifest:',len(packages),'packages; passed=',report['all_passed'])
if not report['all_passed']:raise SystemExit(1)
