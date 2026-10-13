#!/bin/bash
# Reclaim only unused SDKs on a disposable GitHub-hosted VM.
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "${RUNNER_ENVIRONMENT:-}" = github-hosted
test "$(id -u)" != 0
export PROJECT_ROOT=/data/disk2/lyy_dataset/openwrt
mkdir -p "$PROJECT_ROOT"/{work/tmp,logs,cache,artifacts}
{
  uname -a
  /usr/bin/gcc --version | head -1
  /usr/bin/python3 --version
  printf 'Inherited nofile soft=%s hard=%s\n' "$(ulimit -Sn)" "$(ulimit -Hn)"
  free -h
  df -h "$PROJECT_ROOT"
} > "$PROJECT_ROOT/logs/ci-environment-before.log"
# These are runner-image SDKs, never user projects or paths on the local server.
sudo python3 - <<'PY'
import pathlib,shutil
for name in ['/usr/share/dotnet','/usr/local/lib/android','/opt/ghc',
             '/opt/hostedtoolcache','/usr/local/share/powershell','/usr/share/swift']:
    p=pathlib.Path(name)
    if p.is_dir() and not p.is_symlink():
        print('Removing unused hosted-image SDK:',p)
        shutil.rmtree(p)
PY
df -h "$PROJECT_ROOT" | tee "$PROJECT_ROOT/logs/ci-environment-after.log"
python3 - <<'PY'
import shutil
free=shutil.disk_usage('/data/disk2/lyy_dataset/openwrt').free
minimum=55*1024**3
print('Available GiB:',round(free/1024**3,2),'Required initial GiB:',55)
if free<minimum:
    raise SystemExit('Insufficient hosted-runner storage for a full source build plus the 20 GiB reserve. Use a larger runner; no release will be published.')
PY
