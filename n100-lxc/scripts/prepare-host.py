#!/usr/bin/python3
"""Install checksum-locked host helpers in the project; never use sudo."""
import hashlib, json, os, pathlib, subprocess, urllib.request

root = pathlib.Path(os.environ['PROJECT_ROOT'])
base = pathlib.Path(__file__).resolve().parents[1]
prefix = root / 'work/tools/prefix'
bindir = root / 'work/tools/bin'
bindir.mkdir(parents=True, exist_ok=True)
for item in json.loads((base / 'locks/host-debs.json').read_text()):
    target = root / 'cache/debs' / item['filename']
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        urllib.request.urlretrieve(item['url'], target)
    if hashlib.sha256(target.read_bytes()).hexdigest() != item['sha256']:
        raise SystemExit('Host dependency checksum mismatch: ' + str(target))
    subprocess.run(['dpkg-deb', '-x', str(target), str(prefix)], check=True)
for source in (prefix / 'usr/bin').iterdir():
    if not source.is_file():
        continue
    name = source.name
    target = bindir / name
    if target.is_symlink():
        target.unlink()
    if name.endswith('.sh'):
        target.symlink_to(source)
        continue
    content = '#!/bin/sh\nP="' + str(prefix) + '"\n'
    content += 'export LD_LIBRARY_PATH="$P/usr/lib/x86_64-linux-gnu:$P/lib/x86_64-linux-gnu"\n'
    if name == 'bison':
        content += 'export BISON_PKGDATADIR="$P/usr/share/bison"\n'
    if name == 'file':
        content += 'export MAGIC="$P/usr/share/misc/magic.mgc"\n'
    if name == 'proot':
        content += 'export PROOT_TMP_DIR="' + str(root / 'work/tmp') + '"\n'
    content += 'exec "$P/usr/bin/' + name + '" "$@"\n'
    target.write_text(content)
    target.chmod(0o755)
awk = bindir / 'awk'
if awk.exists() or awk.is_symlink():
    awk.unlink()
awk.symlink_to('gawk')
for name in ['gcc', 'g++']:
    target = bindir / name
    target.write_text('#!/bin/sh\nexec /usr/bin/' + name + ' "$@" -idirafter "' + str(prefix / 'usr/include')
                      + '" -L"' + str(prefix / 'usr/lib/x86_64-linux-gnu') + '"\n')
    target.chmod(0o755)
print('Project-local host tools ready:', prefix)
