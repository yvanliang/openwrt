#!/bin/bash
# Reapply local source fixes after refreshing vendored upstream packages.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE/.."
for name in passwall2-nofile openclash-lxc zerotier-luci-openwrt; do
  patch="$BASE/patches/$name.diff"
  if git apply --check --directory=package/n100-lxc "$patch" 2>/dev/null; then
    git apply --directory=package/n100-lxc "$patch"
    echo "Applied: $name"
  elif git apply --reverse --check --directory=package/n100-lxc "$patch" 2>/dev/null; then
    echo "Already applied: $name"
  else
    echo "Source no longer matches $patch; review the upstream change before building." >&2
    exit 1
  fi
done
