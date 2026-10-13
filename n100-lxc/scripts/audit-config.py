#!/usr/bin/python3
import json,pathlib,re

tree=pathlib.Path(__file__).resolve().parents[2]
base=tree/'n100-lxc'
config=(tree/'.config').read_text()
required=['luci-base','luci-mod-admin-full','luci-app-package-manager','luci-i18n-base-zh-cn',
          'uhttpd','uhttpd-mod-ubus','dropbear','firewall4','dnsmasq-full','ip-full',
          'luci-app-passwall2','luci-app-ssr-plus','luci-app-openclash','sing-box','xray-core',
          'mihomo','haproxy','shadowsocksr-libev-ssr-local','shadowsocksr-libev-ssr-redir',
          'ruby','ruby-yaml','zerotier','luci-app-zerotier','luci-i18n-zerotier-zh-cn','vlmcsd','ca-bundle']
missing=[x for x in required if 'CONFIG_PACKAGE_'+x+'=y\n' not in config]
if 'CONFIG_PACKAGE_dnsmasq_full_nftset=y\n' not in config:
    missing.append('dnsmasq_full_nftset')
requested=set(re.findall(r'^(CONFIG_[^= ]+)=y$',(base/'config/seed.config').read_text(),re.M))
effective=set(re.findall(r'^(CONFIG_[^= ]+)=y$',config,re.M))
report={'required_missing':missing,'seed_y_dropped':sorted(requested-effective),
        'effective_packages':sorted(re.findall(r'^CONFIG_PACKAGE_([^=]+)=y$',config,re.M))}
toolchains=json.loads((base/'locks/toolchains.json').read_text())
versions={x['component']:x['version'] for x in toolchains['source_components']}
mismatch={}
for component,symbol in [('gcc','GCC'),('binutils','BINUTILS')]:
 match=re.search(r'^CONFIG_'+symbol+r'_VERSION="([^"]+)"$',config,re.M)
 actual=match.group(1) if match else ''
 if actual!=versions[component]:mismatch[component]={'configured':actual,'locked':versions[component]}
report['compiler_lock_mismatch']=mismatch
(base/'config/config-audit.json').write_text(json.dumps(report,indent=2)+'\n')
if missing:
    raise SystemExit('Required package/config missing: '+', '.join(missing))
if mismatch:raise SystemExit('Refresh toolchains.json for the selected stable base: '+json.dumps(mismatch))
print('Required packages and nftset selected; inspect config-audit.json for seed differences')
