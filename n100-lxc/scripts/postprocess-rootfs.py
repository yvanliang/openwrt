#!/usr/bin/python3
"""Transform the built archive without losing uid/gid, modes or symlinks."""
import argparse, hashlib, io, json, os, pathlib, re, tarfile, gzip

p=argparse.ArgumentParser()
p.add_argument('source'); p.add_argument('destination'); args=p.parse_args()
base=pathlib.Path(__file__).resolve().parents[1]
epoch=int(os.environ.get('SOURCE_DATE_EPOCH','1782770622'))
new={}
def put(name,data,mode=0o644):
    t=tarfile.TarInfo(name);t.uid=t.gid=0;t.uname=t.gname='root';t.mode=mode;t.mtime=epoch
    if isinstance(data,str):data=data.encode()
    t.size=len(data);new[name]=(t,data)

put('etc/n100-lxc','OpenWrt userspace; kernel and modules are supplied by the PVE host.\n')
put('etc/config/network',"""config interface 'loopback'
 option device 'lo'
 option proto 'static'
 option ipaddr '127.0.0.1'
 option netmask '255.0.0.0'
config interface 'lan'
 option device 'eth0'
 option proto 'dhcp'
 option defaultroute '0'
 option peerdns '0'
 option ipv6 '0'
""")
put('etc/config/dhcp',"""config dnsmasq
 option domainneeded '1'
 option boguspriv '1'
 option localise_queries '1'
 option rebind_protection '1'
 option local '/lan/'
 option domain 'lan'
 option expandhosts '1'
 option authoritative '0'
 option readethers '0'
 option leasefile '/tmp/dhcp.leases'
 option noresolv '1'
 list server '223.5.5.5'
 option localservice '1'
 option cachesize '1000'
config dhcp 'lan'
 option interface 'lan'
 option ignore '1'
 option dhcpv4 'disabled'
 option dhcpv6 'disabled'
 option ra 'disabled'
 option ndp 'disabled'
""")
put('etc/config/firewall',"""config defaults
 option input 'REJECT'
 option output 'ACCEPT'
 option forward 'REJECT'
 option synflood_protect '1'
 option flow_offloading '0'
 option flow_offloading_hw '0'
config zone
 option name 'lan'
 list network 'lan'
 option input 'ACCEPT'
 option output 'ACCEPT'
 option forward 'ACCEPT'
""")
put('etc/config/zerotier',"""config zerotier 'global'
 option enabled '0'
 option port '9993'
 option secret ''
""")
put('etc/inittab','::sysinit:/etc/init.d/rcS S boot\n::shutdown:/etc/init.d/rcS K shutdown\nconsole::askfirst:/usr/libexec/login.sh\n')
put('etc/sysctl.d/99-n100-lxc.conf',"""net.ipv4.ip_forward=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.eth0.send_redirects=0
net.ipv4.conf.eth0.accept_redirects=0
""")
put('sbin/kmodloader',"""#!/bin/sh
# The container cannot load OpenWrt modules into a PVE kernel.
case "${0##*/}" in
 kmodloader) exit 0 ;;
 lsmod) exec /usr/libexec/n100-kmod-query/lsmod "$@" ;;
 modinfo)
  kernel=$(uname -r)
  if [ ! -d "/lib/modules/$kernel" ]; then
   echo "No module metadata for running kernel $kernel in this container; run modinfo on the PVE host." >&2
   exit 1
  fi
  exec /usr/libexec/n100-kmod-query/modinfo "$@"
  ;;
 *) echo 'Kernel modules must be managed on the PVE host.' >&2; exit 1 ;;
esac
""",0o755)
put('etc/uci-defaults/zzzz-n100-lxc',"""#!/bin/sh
# Run after plugin initialization, which creates UCI sections and changes GSO.
uci -q set passwall2.@global[0].enabled='0'
uci -q set passwall2.@global[0].fake_dns='0'
uci -q set passwall2.@global[0].ipv6_proxy='0'
uci -q set passwall2.@global[0].direct_dns_query_strategy='UseIPv4'
uci -q set passwall2.@global[0].remote_dns_query_strategy='UseIPv4'
uci -q set passwall2.@global_app[0].xray_file='/usr/bin/xray'
uci -q set shadowsocksr.@global[0].global_server='nil'
uci -q set shadowsocksr.@global[0].enable='0'
uci -q set openclash.config.enable='0'
uci -q set openclash.config.auto_update='0'
uci -q set openclash.config.core_version='linux-amd64-v1'
uci -q set openclash.config.disable_quic_go_gso='0'
uci -q set openclash.config.geo_auto_update='0'
uci -q set openclash.config.geoip_auto_update='0'
uci -q set openclash.config.geosite_auto_update='0'
uci -q set openclash.config.geoasn_auto_update='0'
uci -q set openclash.config.en_mode='redir-host'
uci -q set openclash.config.operation_mode='redir-host'
uci -q set openclash.config.ipv6_enable='0'
uci -q set openclash.config.ipv6_dns='0'
uci -q set zerotier.global.enabled='0'
uci -q set vlmcsd.config.enabled='0'
uci commit
for s in passwall2 shadowsocksr openclash haproxy sysntpd sysfixtime; do
 /etc/init.d/$s disable 2>/dev/null || true
done
exit 0
""",0o755)
for f in (base/'target').glob('*'):
    if f.is_file():put('usr/sbin/'+f.name,f.read_bytes(),0o755)
entries=[];mihomo=None;module_query=None;data_files={}
with tarfile.open(args.source,'r:gz') as archive:
    for t in archive:
        if t.name.startswith('./'):t.name=t.name[2:]
        if t.name in ['', '.']:continue
        if t.name=='etc/openclash/config/n100-direct-example.yaml':continue
        name=t.name
        if name.startswith('/') or '..' in pathlib.PurePosixPath(name).parts:raise SystemExit('Unsafe tar path')
        data=archive.extractfile(t).read() if t.isfile() else None
        if name=='usr/libexec/mihomo':mihomo=data
        if name=='sbin/kmodloader':module_query=data
        if name in ['usr/share/v2ray/geoip.dat','usr/share/v2ray/geosite.dat']:data_files[name]=data
        if re.match(r'etc/rc.d/[SK]\d+(passwall2|shadowsocksr|openclash|haproxy|sysntpd|sysfixtime)$',name):continue
        if name.startswith('etc/dropbear/dropbear_') or name.startswith('var/lib/zerotier-one/identity.'):continue
        if name in ['etc/init.d/dnsmasq','etc/init.d/vlmcsd'] and data:
            original=data
            data=re.sub(rb'\bprocd_add_jail([a-z_]*)\b',rb': procd_add_jail\1',data)
            patch_record=base/'patches'/('lxc-'+name.split('/')[-1]+'.diff')
            import difflib
            patch_record.write_text(''.join(difflib.unified_diff(original.decode().splitlines(True),data.decode().splitlines(True),fromfile=name,tofile=name)))
            t.size=len(data)
        if name in new:continue
        entries.append((t,data))
if not mihomo:raise SystemExit('Source-built Mihomo missing')
if not module_query:raise SystemExit('Source-built module query engine missing')
put('usr/libexec/n100-kmod-query/engine',module_query,0o755)
for name in ['lsmod','modinfo']:
    link=tarfile.TarInfo('usr/libexec/n100-kmod-query/'+name)
    link.type=tarfile.SYMTYPE;link.linkname='engine';link.uid=link.gid=0
    link.uname=link.gname='root';link.mode=0o777;link.mtime=epoch
    new[link.name]=(link,None)
put('etc/openclash/core/clash_meta',mihomo,0o755)
for name,data in data_files.items():
    put('etc/openclash/'+('GeoIP.dat' if name.endswith('/geoip.dat') else 'GeoSite.dat'),data)
if len(data_files)!=2:raise SystemExit('Required locked geodata missing')
entries=[entry for entry in entries if entry[0].name not in new]
entries.extend(new.values())
with open(args.destination,'wb') as f:
    with gzip.GzipFile(fileobj=f,mode='wb',filename='',mtime=epoch,compresslevel=9) as z:
        with tarfile.open(fileobj=z,mode='w',format=tarfile.PAX_FORMAT) as out:
            for t,data in sorted(entries,key=lambda x:x[0].name):
                out.addfile(t,io.BytesIO(data) if data is not None else None)
print(json.dumps({'archive':args.destination,'sha256':hashlib.sha256(pathlib.Path(args.destination).read_bytes()).hexdigest(),
                  'core_source':'source-built shared Mihomo; all SSR Xray patches retained',
                  'host_module_policy':'autoload suppressed; dependency metadata and .ko files retained'}))
