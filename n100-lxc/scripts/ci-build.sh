#!/bin/bash
# Source build and userspace checks only; no QEMU or PVE operations.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
TREE=$(cd "$BASE/.." && pwd)
cd "$TREE"
mkdir -p "$PROJECT_ROOT"/{work/tmp,logs,artifacts,cache/debs}
if [ -n "${GITHUB_SHA:-}" ]; then
  test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
fi
JOBS=${JOBS:-$(python3 - <<'PY'
import os
memory=int(next(x.split()[1] for x in open('/proc/meminfo') if x.startswith('MemAvailable:')))
print(max(1,min(32,os.cpu_count() or 1,memory//(2*1024*1024))))
PY
)}
export JOBS
python3 "$BASE/scripts/prepare-host.py"
bash "$BASE/scripts/prepare-source.sh" > "$PROJECT_ROOT/logs/ci-prepare-source.log" 2>&1
bash "$BASE/scripts/build.sh"
bash "$BASE/scripts/release.sh"
OUT=$(cat "$PROJECT_ROOT/work/latest-release.txt")
bash "$BASE/scripts/verify-userspace.sh" "$OUT"
bash "$BASE/scripts/verify-xray-patches.sh" "$OUT"
python3 "$BASE/scripts/audit-binaries.py" "$(cat "$PROJECT_ROOT/work/last-userspace-root.txt")" --report "$OUT/binary-audit.json"
python3 "$BASE/scripts/verify-generated-configs.py" "$OUT/generated-test-configs" --report "$OUT/generated-config-verification.json"
python3 "$BASE/scripts/lock-inputs.py"
cp "$BASE/locks/source-lock.json" "$OUT/source-lock.json"
cp "$BASE/locks/source-lock.json" "$OUT/locks/source-lock.json"
python3 "$BASE/scripts/verify-inputs.py" --require-all > "$OUT/input-verification.json"
python3 "$BASE/scripts/package-release.py" "$OUT"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  printf 'directory=%s\n' "$OUT" >> "$GITHUB_OUTPUT"
  printf 'publish_directory=%s\n' "$OUT/publish" >> "$GITHUB_OUTPUT"
  printf 'release_tag=lxc-25.12.5-%s-%s\n' "$GITHUB_RUN_ID" "$GITHUB_RUN_ATTEMPT" >> "$GITHUB_OUTPUT"
fi
