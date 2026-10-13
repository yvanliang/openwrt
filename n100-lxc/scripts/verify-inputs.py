#!/usr/bin/python3
"""Check the recorded input bytes; report absent caches separately."""
import hashlib,json,os,pathlib,sys
base=pathlib.Path(__file__).resolve().parents[1]
lock=json.loads((base/'locks/source-lock.json').read_text())
dl=pathlib.Path(os.environ['PROJECT_ROOT'])/'cache/downloads/openwrt'
missing=[];mismatch=[];verified=0;counts={}
root=pathlib.Path(os.environ['PROJECT_ROOT'])
groups=[('downloads',[(dl/x['path'],x['sha256']) for x in lock['downloaded_sources']]),
 ('recipes',[(base.parent/x['path'],x['sha256']) for x in lock['vendored_recipe_files']]),
 ('host_debs',[(root/'cache/debs'/x['filename'],x['sha256']) for x in lock['host_dependencies']])]
for category,records in groups:
 counts[category]=0
 for p,expected in records:
  if not p.is_file():missing.append(str(p));continue
  h=hashlib.sha256()
  with p.open('rb') as f:
   for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
  if h.hexdigest()!=expected:mismatch.append(str(p))
  else:verified+=1;counts[category]+=1
report={'verified':verified,'categories':counts,'missing':missing,'mismatch':mismatch}
print(json.dumps(report,indent=2))
if mismatch or (missing and '--require-all' in sys.argv):raise SystemExit(1)
