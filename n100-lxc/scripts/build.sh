#!/bin/bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
cd "$BASE/.."
mkdir -p "$PROJECT_ROOT/logs"
exec 9>"$PROJECT_ROOT/work/build.lock"
flock -n 9 || { echo 'Another build is running'; exit 1; }
JOBS=${JOBS:-32}
TAG=$(python3 -c 'import json; print(json.load(open("n100-lxc/locks/repositories.json"))["openwrt"]["tag"])')
export SOURCE_DATE_EPOCH=$(python3 "$BASE/scripts/source-epoch.py")
check_space() {
  local bytes
  bytes=$(df -B1 --output=avail "$PROJECT_ROOT" | tail -1)
  [ "$bytes" -ge 21474836480 ] || { echo 'Less than 20 GiB free; stop and inspect project caches.'; return 1; }
}
check_space
make prereq
python3 "$BASE/scripts/audit-config.py"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
make -j"$JOBS" download V=s > "$PROJECT_ROOT/logs/download-$stamp.log" 2>&1
check_space
setsid make -j"$JOBS" V=s > "$PROJECT_ROOT/logs/build-$stamp.log" 2>&1 &
builder=$!
stop_builder() { kill -TERM -- -"$builder" 2>/dev/null || true; }
trap 'stop_builder; exit 130' INT
trap 'stop_builder; exit 143' TERM
while kill -0 "$builder" 2>/dev/null; do
  if ! check_space; then
    stop_builder
    wait "$builder" || true
    exit 1
  fi
  { date -u; df -h "$PROJECT_ROOT"; free -h; } >> "$PROJECT_ROOT/logs/resources-$stamp.log"
  sleep 30
done
wait "$builder"
echo "Source build completed; log: $PROJECT_ROOT/logs/build-$stamp.log"
