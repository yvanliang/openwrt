#!/usr/bin/python3
"""Use the stable tag's published version.date, matching OpenWrt itself."""
import json,pathlib,subprocess,sys
base=pathlib.Path(__file__).resolve().parents[1]
tag=json.loads((base/'locks/repositories.json').read_text())['openwrt']['tag']
result=subprocess.run(['git','-C',str(base.parent),'show',tag+':version.date'],text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
if result.returncode==0:
 value=result.stdout.strip();origin=tag+':version.date'
else:
 value=subprocess.check_output(['git','-C',str(base.parent),'show','-s','--format=%ct',tag+'^{commit}'],text=True).strip()
 origin=tag+'^{commit}:committer_timestamp'
if not value.isdigit():raise SystemExit('Non-numeric stable source timestamp')
data={'epoch':int(value),'origin':origin}
print(json.dumps(data) if '--json' in sys.argv else value)
