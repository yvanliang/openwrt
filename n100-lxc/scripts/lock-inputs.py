#!/usr/bin/python3
import hashlib,json,os,pathlib,subprocess
base=pathlib.Path(__file__).resolve().parents[1]
root=pathlib.Path(os.environ['PROJECT_ROOT']);tree=base.parent
def digest(path):
 h=hashlib.sha256()
 with open(path,'rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
records=[]
dl=root/'cache/downloads/openwrt'
for p in sorted(dl.rglob('*')):
 if not p.is_file() or p.name.endswith(('.tmp','.lock','.partial')):continue
 if 'go-mod-cache' in p.parts and not p.name.endswith(('.zip','.ziphash','.mod','.info')):continue
 records.append({'path':str(p.relative_to(dl)),'bytes':p.stat().st_size,'sha256':digest(p)})
recipes=[]
for folder in [tree/'package/n100-lxc',base/'toolchain/golang',tree/'package/libs/readline',base/'patches']:
 for p in sorted(folder.rglob('*')):
  if p.is_file():recipes.append({'path':str(p.relative_to(tree)),'sha256':digest(p)})
lock={'schema':1,'repositories':json.loads((base/'locks/repositories.json').read_text()),
      'providers':json.loads((base/'locks/providers.json').read_text()),
      'host_dependencies':json.loads((base/'locks/host-debs.json').read_text()),
      'rule_data':json.loads((base/'locks/data.json').read_text()),
      'toolchains':json.loads((base/'locks/toolchains.json').read_text()),
      'downloaded_sources':records,'vendored_recipe_files':recipes,
      'go_toolchain':'source-built Go 1.27.1 with source-built bootstrap chain',
      'cpu_baseline':{'c':'OpenWrt generic x86-64','go':'GOAMD64=v1','native_tuning':False},
      'source_date_epoch':int(subprocess.check_output(['python3',str(base/'scripts/source-epoch.py')],text=True)),
      'source_date_epoch_provenance':json.loads(subprocess.check_output(['python3',str(base/'scripts/source-epoch.py'),'--json'],text=True)),
      'licenses':'Original recipes retain PKG_LICENSE/PKG_LICENSE_FILES; Go modules retain go.mod/go.sum and upstream license files. GeoIP CC-BY-SA-4.0; GeoSite MIT.'}
def check(v):
 if v is None:raise SystemExit('null forbidden in build lock')
 if isinstance(v,dict):
  for x in v.values():check(x)
 if isinstance(v,list):
  for x in v:check(x)
check(lock)
(base/'locks/source-lock.json').write_text(json.dumps(lock,indent=2)+'\n')
print('Locked',len(records),'downloaded inputs and',len(recipes),'recipe files')
