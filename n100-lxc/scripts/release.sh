#!/bin/bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
cd "$BASE/.."
TAG=$(python3 -c 'import json; print(json.load(open("n100-lxc/locks/repositories.json"))["openwrt"]["tag"])')
export SOURCE_DATE_EPOCH=$(python3 "$BASE/scripts/source-epoch.py")
COMMIT=$(git rev-parse HEAD)
BUILD_ID="${TAG#v}-n100-lxc-$(date -u +%Y%m%dT%H%M%SZ)-${COMMIT:0:12}"
OUT="$PROJECT_ROOT/artifacts/$BUILD_ID"
mkdir -p "$OUT"
SOURCE=bin/targets/x86/64/openwrt-x86-64-generic-rootfs.tar.gz
[ -s "$SOURCE" ] || { echo 'No source-built generic rootfs tar.gz found'; exit 1; }
python3 "$BASE/scripts/lock-inputs.py"
python3 "$BASE/scripts/postprocess-rootfs.py" "$SOURCE" "$OUT/rootfs.tar.gz" | tee "$OUT/postprocess.json"
python3 "$BASE/scripts/verify-archive.py" "$OUT/rootfs.tar.gz" --report "$OUT/archive-verification.json"
cp .config "$OUT/final.config"
./scripts/diffconfig.sh > "$OUT/diffconfig"
find bin/targets/x86/64 -maxdepth 1 -name '*.manifest' -exec cp '{}' "$OUT/" \;
MANIFEST=$(find "$OUT" -maxdepth 1 -name '*.manifest' -print -quit)
python3 "$BASE/scripts/verify-manifest.py" "$MANIFEST" --report "$OUT/manifest-verification.json"
cp "$BASE/locks/source-lock.json" "$OUT/source-lock.json"
cp "$BASE/locks/providers.json" "$OUT/providers.json"
cp -a "$BASE/scripts" "$OUT/"
cp -a "$BASE/docs" "$OUT/"
cp "$BASE/README.md" "$OUT/"
cp -a "$BASE/tests" "$OUT/"
cp -a "$BASE/target" "$OUT/"
cp -a "$BASE/locks" "$OUT/"
cp -a "$BASE/config/config-audit.json" "$OUT/"
printf 'BUILD_ID=%s\nGIT_COMMIT=%s\nGIT_BRANCH=%s\nUPSTREAM_TAG=%s\nFORK=%s\n' \
 "$BUILD_ID" "$COMMIT" "$(git branch --show-current)" "$TAG" "$(git remote get-url origin)" > "$OUT/BUILD-INFO"
printf '%s\n' "$OUT" > "$PROJECT_ROOT/work/latest-release.txt"
echo "Release: $OUT"
