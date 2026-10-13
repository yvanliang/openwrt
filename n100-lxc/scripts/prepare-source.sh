#!/bin/bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
TREE=$(cd "$BASE/.." && pwd)
cd "$TREE"
mkdir -p "$PROJECT_ROOT"/{cache/downloads/openwrt,work/tmp,logs,artifacts}
bash "$BASE/scripts/apply-source-patches.sh"
cp "$BASE/config/feeds.conf" feeds.conf
./scripts/feeds update -a
# The Go recipe is vendored from a recorded upstream commit, not moving master.
rm -rf feeds/packages/lang/golang
cp -a "$BASE/toolchain/golang" feeds/packages/lang/golang
./scripts/feeds update -i packages
./scripts/feeds install -a
# Explicit custom providers beat duplicate recipes. Keep official dnsmasq/iproute2.
python3 - "$BASE/locks/providers.json" <<'PY'
import json,pathlib,sys
providers=json.load(open(sys.argv[1]))
for feed in pathlib.Path('package/feeds').iterdir():
    for name in providers:
        p=feed/name
        if p.is_symlink() and (pathlib.Path('package/n100-lxc')/name).exists():
            p.unlink()
PY
if [ ! -e dl ]; then ln -s "$PROJECT_ROOT/cache/downloads/openwrt" dl; fi
cp "$BASE/config/seed.config" .config
make defconfig
cp .config "$BASE/config/final.config"
./scripts/diffconfig.sh > "$BASE/config/diffconfig"
python3 "$BASE/scripts/audit-config.py"
