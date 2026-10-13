#!/usr/bin/python3
"""Package verified artifacts and generic English release notes."""
import argparse,datetime,gzip,hashlib,json,os,pathlib,shutil,tarfile
p=argparse.ArgumentParser()
p.add_argument('directory');p.add_argument('--origin',choices=['github-actions','local'],default='github-actions' if os.environ.get('GITHUB_ACTIONS')=='true' else 'local')
a=p.parse_args();out=pathlib.Path(a.directory).resolve()
base=pathlib.Path(__file__).resolve().parents[1];tree=base.parent
archive=json.loads((out/'archive-verification.json').read_text())
manifest=json.loads((out/'manifest-verification.json').read_text())
generated=json.loads((out/'generated-config-verification.json').read_text())
assert archive['all_passed'] and manifest['all_passed'] and generated['all_passed']
assert 'PASS: userspace version and generated configuration checks.' in (out/'userspace-verification.log').read_text()
binary=json.loads((out/'binary-audit.json').read_text())
assert all(x['goamd64_v1'] and x['aes_instruction_count']>0 for x in binary['binaries'].values())
input_file=out/'input-verification.json'
if not input_file.exists():input_file=out/'evidence/input-verification-final.json'
inputs=json.loads(input_file.read_text())
assert inputs['verified']>0 and not inputs['missing'] and not inputs['mismatch']
patch_log=out/'xray-patch-tests.log'
if not patch_log.exists():patch_log=out/'evidence/xray-patch-tests.log'
assert '\nPASS\n' in patch_log.read_text() and '--- FAIL:' not in patch_log.read_text()
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
assert sha(out/'rootfs.tar.gz')==archive['sha256']
publish=out/'publish';publish.mkdir(exist_ok=False)
shutil.copy2(out/'rootfs.tar.gz',publish/'rootfs.tar.gz')
shutil.copy2(tree/'N100-LXC.md',publish/'N100-LXC.md')
info={}
for line in (out/'BUILD-INFO').read_text().splitlines():
 if '=' in line:
  k,v=line.split('=',1);info[k]=v
info.update({'BUILD_ORIGIN':a.origin,'ROOTFS_SHA256':archive['sha256'],
 'CREATED_UTC':datetime.datetime.utcnow().isoformat()+'Z',
 'GITHUB_RUN_URL':(f'https://github.com/{os.environ["GITHUB_REPOSITORY"]}/actions/runs/{os.environ["GITHUB_RUN_ID"]}' if os.environ.get('GITHUB_RUN_ID') else 'not a GitHub Actions build'),
 'QEMU_TESTED':False,'PVE_TARGET_TESTED':False,'N100_PERFORMANCE_TESTED':False})
(publish/'BUILD-INFO.json').write_text(json.dumps(info,indent=2)+'\n')
names=['final.config','diffconfig','source-lock.json','providers.json',
       'archive-verification.json','manifest-verification.json','generated-config-verification.json',
       'binary-audit.json','userspace-verification.log','userspace-test-adjustments.json',
       'input-verification.json','xray-patch-tests.log']
names.extend(x.name for x in out.glob('*.manifest'))
with tarfile.open(publish/'build-details.tar.gz','w:gz') as t:
 for name in names:
  if (out/name).is_file():t.add(out/name,arcname=name,recursive=False)
 if input_file.parent!=out:t.add(input_file,arcname='input-verification.json',recursive=False)
 if patch_log.parent!=out:t.add(patch_log,arcname='retained-patch-tests.log',recursive=False)
 for folder in ['locks','generated-test-configs']:
  if (out/folder).is_dir():t.add(out/folder,arcname=folder)
 t.add(tree/'N100-LXC.md',arcname='N100-LXC.md',recursive=False)
logs=pathlib.Path(os.environ.get('PROJECT_ROOT','/data/disk2/lyy_dataset/openwrt'))/'logs'
with tarfile.open(publish/'build-logs.tar.gz','w:gz') as t:
 for prefix in ['build-','download-','resources-','ci-']:
  for f in sorted(logs.glob(prefix+'*.log')):t.add(f,arcname=f.name,recursive=False)
notes=f'''# OpenWrt 25.12.5 for PVE LXC (x86-64)

Build origin: **{a.origin}**. This release contains a source-built LXC root filesystem,
additional apps, pinned build inputs, configuration records, and verification evidence.

Rootfs SHA256: `{archive['sha256']}`.

Source compilation, archive/package inspection, and userspace configuration checks passed.

Download `rootfs.tar.gz`. Read `N100-LXC.md`
for changes, source build instructions, CI behavior, and target acceptance requirements.
'''
(publish/'RELEASE-NOTES.md').write_text(notes)
print('Release asset directory:',publish)
