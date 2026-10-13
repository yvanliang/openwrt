-- Synthetic local nodes for generator/schema checks; no credentials or listeners.
local uci = require('luci.model.uci').cursor()
local json = require('luci.jsonc')
uci:set('passwall2', 'n100test', 'nodes')
uci:set('passwall2', 'n100test', 'type', 'Xray')
uci:set('passwall2', 'n100test', 'protocol', 'socks')
uci:set('passwall2', 'n100test', 'address', '127.0.0.1')
uci:set('passwall2', 'n100test', 'port', '19090')
uci:set('passwall2', 'n100test', 'tls', '0')
uci:set('passwall2', 'n100test', 'transport', 'raw')
uci:commit('passwall2')
local function save(path, data)
 local f=assert(io.open(path,'w'));f:write(data);f:close()
end
local xray=require('luci.passwall2.util_xray')
save('/tmp/checks/pw2-xray.json',xray.gen_config({flag='n100check',node='n100test',no_run=true,
 local_socks_address='127.0.0.1',local_socks_port='19084',
 direct_dns_udp_server='192.168.0.3',direct_dns_udp_port='53',
 remote_dns_tcp_server='192.168.0.4',remote_dns_tcp_port='53',
 dns_listen_port='19085',direct_dns_query_strategy='UseIPv4',
 remote_dns_query_strategy='UseIPv4',remote_dns_detour='direct'}))
uci:set('passwall2','n100test','type','sing-box')
uci:set('passwall2','n100test','transport','tcp')
uci:commit('passwall2')
local sing=require('luci.passwall2.util_sing-box')
save('/tmp/checks/pw2-sing-box.json',sing.gen_config({flag='n100singcheck',node='n100test',no_run=true,
 local_socks_address='127.0.0.1',local_socks_port='19086',
 direct_dns_udp_server='192.168.0.3',direct_dns_udp_port='53',
 remote_dns_tcp_server='192.168.0.4',remote_dns_tcp_port='53',
 dns_listen_port='19087',direct_dns_query_strategy='UseIPv4',
 remote_dns_query_strategy='UseIPv4',remote_dns_detour='direct'}))
uci:set('shadowsocksr','n100test','servers')
uci:set('shadowsocksr','n100test','type','v2ray')
uci:set('shadowsocksr','n100test','v2ray_protocol','socks')
uci:set('shadowsocksr','n100test','server','127.0.0.1')
uci:set('shadowsocksr','n100test','server_port','19090')
uci:set('shadowsocksr','n100test','tls','0')
uci:set('shadowsocksr','n100test','transport','tcp')
uci:set('shadowsocksr','n100test','insecure','0')
uci:commit('shadowsocksr')
print('Synthetic Passwall2 Xray/sing-box configs generated; SSR test node prepared')
