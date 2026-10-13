#!/usr/bin/python3
"""Read ELF metadata/disassembly without executing the target programs."""
import argparse,hashlib,json,pathlib,re,subprocess
p=argparse.ArgumentParser()
p.add_argument('rootfs_directory');p.add_argument('--report',required=True)
args=p.parse_args()
base=pathlib.Path(__file__).resolve().parents[1]
tree=base.parent
go=tree/'staging_dir/hostpkg/lib/go-1.27/bin/go'
records={}
for name,relative in [('xray','usr/bin/xray'),('sing-box','usr/bin/sing-box'),('mihomo','usr/libexec/mihomo')]:
 binary=pathlib.Path(args.rootfs_directory)/relative
 metadata=subprocess.check_output([str(go),'version','-m',str(binary)],text=True)
 process=subprocess.Popen(['/usr/bin/objdump','-d',str(binary)],stdout=subprocess.PIPE,text=True)
 aes=pclmul=0
 for line in process.stdout:
  if re.search(r'\b(?:v?aesenc|v?aesenclast|v?aesdec|v?aesdeclast|aeskeygenassist)\b',line):aes+=1
  if re.search(r'\bv?pclmul[a-z0-9]*\b',line):pclmul+=1
 if process.wait()!=0:raise SystemExit('objdump failed: '+name)
 baseline=bool(re.search(r'GOAMD64=v1\b',metadata))
 records[name]={'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'build_metadata':metadata,'goamd64_v1':baseline,'aes_instruction_count':aes,'pclmul_instruction_count':pclmul}
 if not baseline or not aes:raise SystemExit('Missing CPU baseline or AES code paths: '+name)
report={'binaries':records,'scope':'ELF inspection only. Runtime CPU dispatch, N100 flags and performance remain target tests.'}
pathlib.Path(args.report).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({n:{k:v for k,v in d.items() if k!='build_metadata'} for n,d in records.items()},indent=2))
