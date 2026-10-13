#!/bin/bash
# Prepare a separate worktree. Never merge upstream development into production.
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
source "$BASE/scripts/project-env.sh"
TREE=$(cd "$BASE/.." && pwd)
cd "$TREE"
test -z "$(git status --porcelain)" || { echo 'Commit or preserve local edits before upgrading.'; exit 1; }
NEW_TAG=${1:-}
if [ -z "$NEW_TAG" ]; then
 NEW_TAG=$(gh api repos/openwrt/openwrt/releases/latest --jq 'select(.prerelease==false and .draft==false) | .tag_name')
fi
[[ "$NEW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Only stable release tags accepted.'; exit 2; }
OLD_TAG=$(python3 -c 'import json; print(json.load(open("n100-lxc/locks/repositories.json"))["openwrt"]["tag"])')
[ "$NEW_TAG" != "$OLD_TAG" ] || { echo "Already based on $NEW_TAG"; exit 0; }
gh api "repos/openwrt/openwrt/releases/tags/$NEW_TAG" --jq 'select(.prerelease==false and .draft==false) | .tag_name' | grep -Fx "$NEW_TAG"
git fetch upstream "refs/tags/$NEW_TAG:refs/tags/$NEW_TAG"
BRANCH="n100-pve-lxc/upgrade-${NEW_TAG#v}-$(date -u +%Y%m%dT%H%M%SZ)"
DEST="$PROJECT_ROOT/work/upgrade-${NEW_TAG#v}-$(date -u +%Y%m%dT%H%M%SZ)"
git worktree add -b "$BRANCH" "$DEST" "$NEW_TAG"
# Every customization commit remains reviewable. Conflicts stop in the upgrade tree.
git rev-list --reverse "$OLD_TAG..HEAD" | while read -r commit; do
 git -C "$DEST" cherry-pick "$commit"
done
python3 - "$DEST" "$NEW_TAG" <<'PY'
import json,pathlib,re,subprocess,sys
tree=pathlib.Path(sys.argv[1]);tag=sys.argv[2]
p=tree/'n100-lxc/locks/repositories.json';d=json.loads(p.read_text())
d['openwrt']['tag']=tag
d['openwrt']['commit']=subprocess.check_output(['git','-C',str(tree),'rev-parse',tag+'^{commit}'],text=True).strip()
feeds=(tree/'feeds.conf.default').read_text().replace('https://git.openwrt.org/feed/packages.git','https://github.com/openwrt/packages.git').replace('https://git.openwrt.org/project/luci.git','https://github.com/openwrt/luci.git').replace('https://git.openwrt.org/feed/routing.git','https://github.com/openwrt/routing.git')
feeds='\n'.join(x for x in feeds.splitlines() if not x.startswith(('src-git telephony ','src-git video ')))+'\n'
(tree/'n100-lxc/config/feeds.conf').write_text(feeds)
for line in feeds.splitlines():
 if not line.strip() or line.lstrip().startswith('#'):continue
 _,name,source=line.split();url,sha=source.rsplit('^',1)
 if not re.fullmatch(r'[0-9a-f]{40}',sha):raise SystemExit('Stable feed is not commit-pinned: '+name)
 license=d.get('feed-'+name,{}).get('license','individual package PKG_LICENSE from fixed feed commit')
 d['feed-'+name]={'repository':url,'commit':sha,'license':license}
p.write_text(json.dumps(d,indent=2)+'\n')
providers=tree/'n100-lxc/locks/providers.json'
mapping=json.loads(providers.read_text())
for entry in mapping.values():
 if entry['recipe_repository']=='https://github.com/openwrt/openwrt.git':entry['recipe_commit']=d['openwrt']['commit']
providers.write_text(json.dumps(mapping,indent=2)+'\n')
PY
echo "Upgrade worktree: $DEST"
echo 'Review retained plugin/toolchain pins against stable release APIs; update vendored recipes and provider locks deliberately.'
echo 'Refresh toolchains.json for the new base compiler recipes and hashes before the guarded config audit/build.'
echo 'Then run prepare-host.py, prepare-source.sh, build.sh, release.sh and regression tests in that worktree.'
echo 'Do not cut over or push the upgrade branch until its report records the required verification.'
