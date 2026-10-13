#!/bin/bash
# Upstream SSR patch tests; host userspace, memory pipes and localhost TLS only.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
TREE=$(cd "$BASE/.." && pwd)
OUT=${1:?release directory required}
export GOCACHE="$PROJECT_ROOT/cache/go/xray-tests"
export GOMODCACHE="$PROJECT_ROOT/cache/downloads/openwrt/go-mod-cache"
export GOTMPDIR="$PROJECT_ROOT/work/tmp"
export GOOS=linux GOARCH=amd64 GOAMD64=v1 CGO_ENABLED=0
mkdir -p "$GOCACHE" "$GOMODCACHE"
cd "$TREE/build_dir/target-x86_64_musl/Xray-core-26.9.30"
{
 echo 'Scope: host Go unit tests of retained SSR patches; not CT/PVE or real-node acceptance.'
 "$TREE/staging_dir/hostpkg/lib/go-1.27/bin/go" version
 "$TREE/staging_dir/hostpkg/lib/go-1.27/bin/go" test -p 16 -timeout 120s -mod=readonly \
  ./infra/conf ./proxy/anytls ./proxy/vmess ./proxy/vmess/encoding \
  -run 'Test(AnyTLS|TLSAllowInsecure|VMessAlterID|Legacy)' -v
} 2>&1 | tee "$OUT/xray-patch-tests.log"
