#!/usr/bin/python3
"""Inspect synthetic generator outputs; not a production migration config."""
import argparse,json,pathlib
p=argparse.ArgumentParser();p.add_argument('directory');p.add_argument('--report',required=True);a=p.parse_args()
d=pathlib.Path(a.directory)
x=json.loads((d/'pw2-xray.json').read_text());s=json.loads((d/'pw2-sing-box.json').read_text())
servers={v.get('tag'):v for v in s['dns']['servers']}
checks={
 'singbox_domestic_dns_lan_direct':servers['direct'].get('server')=='192.168.0.3' and servers['direct'].get('detour')=='direct',
 'singbox_foreign_dns_lan_direct':servers['remote'].get('server')=='192.168.0.4' and servers['remote'].get('detour')=='direct',
 'singbox_fakedns_absent':not any(v.get('type')=='fakeip' for v in s['dns']['servers']),
 'xray_dns_destinations':all(ip in json.dumps(x) for ip in ['192.168.0.3','192.168.0.4']),
 'xray_foreign_dns_ipv4_query':any(v.get('address')=='tcp://192.168.0.4:53' and v.get('queryStrategy')=='UseIPv4' for v in x['dns']['servers']),
 'xray_foreign_dns_lan_direct':any('dns-in-default' in v.get('inboundTag',[]) and v.get('outboundTag')=='direct' for v in x['routing']['rules']),
 'xray_fakedns_absent':'fakedns' not in json.dumps(x).lower(),
}
report={'checks':checks,'all_passed':all(checks.values()),
 'scope':'Synthetic DNS destination/detour and configuration inspection only. Real shunt/AAAA policy, source .4 proxy and independent DNS recursion require target traffic.'}
pathlib.Path(a.report).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not report['all_passed']:raise SystemExit(1)
