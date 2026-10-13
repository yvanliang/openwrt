#!/usr/bin/python3
import argparse,hashlib,json,pathlib,re,tarfile
p=argparse.ArgumentParser();p.add_argument('archive');p.add_argument('--report',required=True);args=p.parse_args()
checks={}
with tarfile.open(args.archive,'r:gz') as tf:
    members={m.name.lstrip('./'):m for m in tf}
    def content(name):return tf.extractfile(members[name]).read()
    def record(name,result):checks[name]=bool(result)
    record('root_layout',all(x in members and members[x].isdir() for x in ['bin','etc','sbin','usr']))
    record('init_executable', 'sbin/init' in members and (members['sbin/init'].issym() or members['sbin/init'].mode & 0o111))
    record('root_uid_gid_preserved',members['etc/config/network'].uid==0 and members['etc/config/network'].gid==0)
    record('busybox_symlinks_preserved',members['bin/sh'].issym())
    record('no_readline_install_backups',not any(re.match(r'usr/lib/lib(readline|history)\.so.*\.old$',n) for n in members))
    for path in ['usr/bin/xray','usr/bin/sing-box','usr/libexec/mihomo','etc/openclash/core/clash_meta',
                 'usr/bin/vlmcsd','usr/bin/zerotier-one','usr/sbin/dnsmasq','usr/sbin/nft','sbin/fw4']:
        m=members.get(path)
        record('executable:'+path,m is not None and bool(m.mode&0o111))
    record('mihomo_core_identical',content('usr/libexec/mihomo')==content('etc/openclash/core/clash_meta'))
    for name in ['geoip.dat','geosite.dat']:
        dest='GeoIP.dat' if name=='geoip.dat' else 'GeoSite.dat'
        record('geodata:'+name,content('usr/share/v2ray/'+name)==content('etc/openclash/'+dest) and len(content('usr/share/v2ray/'+name))>1000)
    record('no_zerotier_identity',not any('identity.secret' in n or 'identity.public' in n for n in members))
    record('no_zerotier_prejoined_network',b'config network' not in content('etc/config/zerotier'))
    record('passwall2_soft_nofile_only',re.findall(rb'^[ \t]*ulimit[^\n]*',content('usr/share/passwall2/app.sh'),re.M)==[b'\tulimit -Sn 65535'])
    openclash=content('etc/init.d/openclash')
    record('openclash_soft_nofile_only',re.findall(rb'^[ \t]*ulimit[^\n]*',openclash,re.M)==[b'   ulimit -Sn "$openclash_fd_soft"'])
    record('openclash_procd_inherited_limits',b'/proc/1/limits' in openclash and
           b'procd_set_param limits nofile="$openclash_fd_soft $openclash_fd_hard"' in openclash and
           not re.search(rb'procd_set_param limits[^\n]*(?:nproc|as|memlock)=',openclash))
    record('openclash_no_preselected_example','etc/openclash/config/n100-direct-example.yaml' not in members)
    record('openclash_numeric_defaults',all(b"option "+name+b" '0'" in content('etc/config/openclash')
           for name in [b'auto_restart',b'chnr_auto_update']))
    menu=json.loads(content('usr/share/luci/menu.d/luci-app-zerotier.json'))
    record('zerotier_luci_menu',all(n in menu for n in ['admin/services/zerotier','admin/services/zerotier/config','admin/services/zerotier/interface']))
    record('zerotier_luci_acl', 'luci-app-zerotier' in json.loads(content('usr/share/rpcd/acl.d/luci-app-zerotier.json')))
    record('zerotier_luci_views',all('www/luci-static/resources/view/zerotier/'+n+'.js' in members for n in ['config','interface']))
    record('zerotier_luci_chinese',any(n.endswith('/zerotier.zh-cn.lmo') for n in members))
    record('no_ssh_host_keys',not any(re.match(r'etc/dropbear/dropbear_.*_host_key',n) for n in members))
    record('proxy_autostart_disabled',not any(re.match(r'etc/rc.d/S\d+(passwall2|shadowsocksr|openclash)$',n) for n in members))
    record('standalone_haproxy_disabled',not any(re.match(r'etc/rc.d/S\d+haproxy$',n) for n in members) and b'openclash haproxy sysntpd' in content('etc/uci-defaults/zzzz-n100-lxc'))
    defaults=sorted(n for n in members if n.startswith('etc/uci-defaults/') and members[n].isfile())
    record('defaults_run_after_plugin_initialization',bool(defaults) and defaults[-1]=='etc/uci-defaults/zzzz-n100-lxc')
    record('host_clock_managed',not any(re.match(r'etc/rc.d/S\d+(sysntpd|sysfixtime)$',n) for n in members))
    record('no_fixed_production_address',b'192.168.0.2' not in content('etc/config/network'))
    record('dhcp_ra_disabled',b"option ignore '1'" in content('etc/config/dhcp') and b"option ra 'disabled'" in content('etc/config/dhcp'))
    record('forwarding_redirects',all(x in content('etc/sysctl.d/99-n100-lxc.conf') for x in [b'net.ipv4.ip_forward=1',b'net.ipv4.conf.all.send_redirects=0',b'net.ipv4.conf.all.accept_redirects=0']))
    record('flow_offload_disabled',b"option flow_offloading '0'" in content('etc/config/firewall'))
    record('module_loader_suppressed',b'Kernel modules must be managed on the PVE host' in content('sbin/kmodloader'))
    record('module_queries_preserved',content('usr/libexec/n100-kmod-query/engine').startswith(b'\x7fELF') and
           all(members['usr/libexec/n100-kmod-query/'+n].issym() for n in ['lsmod','modinfo']))
    record('dnsmasq_jail_adapted',not re.search(rb'^\s*procd_add_jail\b',content('etc/init.d/dnsmasq'),re.M))
    record('vlmcsd_jail_user_preserved',b'procd_set_param user vlmcsd' in content('etc/init.d/vlmcsd') and not re.search(rb'^\s*procd_add_jail\b',content('etc/init.d/vlmcsd'),re.M))
    record('vlmcsd_nonroot_account',any(x.startswith(b'vlmcsd:') and x.split(b':')[2]!=b'0' for x in content('etc/passwd').splitlines()))
    record('https_uci',b'listen_https' in content('etc/config/uhttpd'))
    record('chinese_luci',any(n.startswith('usr/lib/lua/luci/i18n/base.zh-cn') or n.startswith('usr/share/ucode/luci/i18n/base.zh-cn') for n in members))
report={'archive':args.archive,'sha256':hashlib.sha256(pathlib.Path(args.archive).read_bytes()).hexdigest(),
        'checks':checks,'all_passed':all(checks.values()),'scope':'Archive static checks only; does not establish PVE or N100 acceptance'}
pathlib.Path(args.report).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not report['all_passed']:raise SystemExit(1)
