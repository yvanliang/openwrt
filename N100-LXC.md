# OpenWrt 25.12.5 for Intel N100 and PVE LXC

This maintenance branch builds an x86-64 OpenWrt userspace template for an
unprivileged PVE LXC container. It is based on the official `v25.12.5` release.
**Additional apps were added.** They remain disabled until configured and
validated. This document intentionally describes those additions generically.

The original template was actually compiled on the build server. Archive,
package, and userspace configuration checks passed.
GitHub Actions results must be assessed separately from that local build.

## Changes in this branch

- Added apps and their required runtime dependencies, Chinese LuCI, SSH,
  HTTPS administration, certificates, and the normal package manager.
- Enabled firewall4/nftables, full DNS support with nftset, complete IP routing
  tools, and useful diagnostics. Removed unused disk-image formats, bootloader
  targets, physical device drivers, and unrelated application stacks.
- Fixed the OpenWrt release, feeds, package providers, source archives,
  rule data, host dependencies, and toolchain recipes in versioned lock files.
  Duplicate package providers are explicitly excluded.
- Built GCC 14.3.0, binutils 2.44, musl 1.2.5, and Go 1.27.1 from source.
  The Go bootstrap chain is source-built as well. Existing system compilers
  are used only to bootstrap the build. Application compatibility patches are
  retained and tested; binary compression is omitted.
- Used generic x86-64 and `GOAMD64=v1`, without `-march=native`. Acceleration
  code paths were inspected, but target CPU dispatch and speed are untested.
- Disabled unnecessary Ruby JIT compilation while preserving YAML support.
  Fixed host header/library precedence and local helper-tool dependencies.
- Fixed repeated library installation leaving backup files in the rootfs.
  Used the release's `version.date` for deterministic archive timestamps.
- Adapted the console, clock services, module-loading entry points, and inner
  service jails for LXC. Real dependency metadata and OpenWrt module files are
  retained. They must never be loaded into the PVE host kernel.
- Preserved read-only module listing. Missing metadata for the real running
  kernel produces an explicit host-diagnosis message, without substituting
  another kernel version.
- Disabled the standalone load-balancer example at boot. Apps can still
  launch the load-balancer with their own validated configuration.
- Changed the app startup file-descriptor setting to adjust only the soft
  limit, preserving the hard limit inherited from the host. A repeatable source
  patch and packaged BusyBox regression check cover this behavior.
- Added a Chinese web management page at **Services → ZeroTier**, with network,
  route and DNS settings matching the official service script. Its imported
  source commit and compatibility patch are locked; service autostart remains
  disabled until configured.
- Kept DHCP/RA and app autostart disabled. No production address, host SSH
  private key, private network identity, subscription, or node secret is seeded.
- Enabled IPv4 forwarding and disabled single-interface gateway redirects.
  Flow offload stays disabled. Normal network offloads are preserved; no CPU
  affinity, special instruction level, or physical NIC tuning is forced.
- Added build, packaging, verification, stable-upgrade, PVE preflight, and
  target acceptance tools. Added a GitHub build-and-release workflow.

## Local source build

All project-owned sources, tools, downloads, caches, temporary files, logs,
and artifacts use `/data/disk2/lyy_dataset/openwrt/`. The environment does not
change `HOME` or `CODEX_HOME` and clears inherited Conda compiler/library settings.
Missing helper tools are unpacked into the project prefix from checksum-locked
packages; no global package installation is required.

Use a non-root x86-64 Linux user with the normal OpenWrt host prerequisites,
at least about 55 GiB initial free space, and sufficient memory. The build
preserves a 20 GiB free-space reserve. A large local server can use `JOBS=32`;
the default CI entry point chooses parallelism from available CPU and memory.

```bash
mkdir -p /data/disk2/lyy_dataset/openwrt/repos
cd /data/disk2/lyy_dataset/openwrt/repos
git clone --branch n100-pve-lxc/25.12.5 \
  https://github.com/yvanliang/openwrt.git openwrt
cd openwrt
source n100-lxc/scripts/project-env.sh
bash n100-lxc/scripts/ci-build.sh
```

For an existing checkout, first preserve local changes, then fetch the desired
maintenance commit. For exact reconstruction, check out the commit recorded in
the release's build metadata instead of following the branch tip.

The entry point prepares locked tools and feeds, resolves configuration,
downloads inputs, compiles the toolchain and selected packages, creates the
rootfs, applies LXC adaptations, checks the archive and installed package list,
and runs userspace/configuration and retained-patch checks. It performs no
QEMU, PVE, production network, or target-machine operation.

Find the resulting directory with:

```bash
cat /data/disk2/lyy_dataset/openwrt/work/latest-release.txt
```

Each directory contains the template, final configuration, diffconfig,
complete package versions, locks, build metadata, and validation evidence.
Its `publish/` subdirectory contains the public Release assets.

Pinned inputs and repeated rootfs packaging support reproducibility. They do
not establish that two independent clean source builds are byte-identical.

## GitHub Actions and Releases

Workflow: `.github/workflows/n100-lxc.yml`.

The workflow first tries a standard GitHub-hosted `ubuntu-22.04` runner. It
checks out the exact triggering commit and stable release tag under the project
root. It removes unused, preinstalled SDKs only on the disposable hosted VM,
then checks actual free space. It does not perform that cleanup on the local
build server. A host that cannot retain the storage reserve fails before
compilation; it never publishes a successful-build claim.

GitHub's standard public Linux runners provide 4 CPUs, 16 GB RAM, and only
14 GB guaranteed storage. Actual recoverable disk space depends on the runner
image, so a successful full build is not assumed. See the
[official runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).
GitHub manages its own runner binaries, action implementation files, and online
workflow logs; project-owned build data stays under the path above.

Relevant pushes to `n100-pve-lxc/25.12.5` automatically build and publish only
after all checks pass. A manual run can disable publication. There are no pull
request triggers, automatic upstream upgrades, QEMU tests, or PVE deployment.
Only the maintenance branch in this fork is accepted by the build job.

For the Actions page's manual Run workflow button, the workflow must exist on
the repository's default branch. The maintenance branch can be selected as
the default without rewriting `main`. See
[GitHub's manual-run requirements](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).

```bash
gh workflow run n100-lxc.yml --repo yvanliang/openwrt \
  --ref n100-pve-lxc/25.12.5 -f publish=true
```

The workflow uses its built-in token with `contents: write` for Releases.
No personal access token, SSH private key, subscription, or target-machine
credential is required. External actions are pinned to complete commit IDs.
Compilation has a six-hour hosted-runner timeout, and diagnostics are uploaded
on failure as well as success. Concurrent builds on the branch are serialized.

A successful run creates a unique `lxc-25.12.5-RUN_ID-ATTEMPT` tag at the exact
source commit. Assets are uploaded to a draft and then published. Existing
release tags/assets are not overwritten. Assets include:

- `rootfs.tar.gz`;
- `BUILD-INFO.json`, this document, and generic English release notes;
- `build-details.tar.gz` with configuration, locks, manifest and verification;
- `build-logs.tar.gz` with source-build and resource logs.

The recorded build origin distinguishes `local` from `github-actions`. An
existing local template uploaded to Releases is not a cloud compilation result.
The workflow's presence or a green source build does not establish PVE/N100
acceptance. If hosted capacity or runtime is insufficient, inspect the failed
run before selecting a larger runner or a separately authorized self-hosted one.

## Target installation and acceptance

Use an unprivileged, unmanaged PVE CT on the existing LAN bridge, with default
AppArmor and only the required TUN device mapping. Start with 2 CPUs, 1024 MiB
memory, no swap, and a 4 GiB rootfs; adjust from actual measurements.

The template's OpenWrt 6.12.94 build kernel is not the CT's running kernel.
The reported target kernel `7.0.14-8-pve` has not been inspected. Built-in and
module support, nft socket/TPROXY, connection tracking, routing, TUN/TAP and
service permissions must be validated on that running PVE kernel.

Userspace checks share the build machine's kernel/PID/network environment.
They do not prove CT boot, isolation, service startup/cleanup, real DNS routing,
transparent TCP/UDP traffic, online package installation, private mesh access,
or protocol-service responses. Synthetic configurations do not reconstruct
production node credentials.

Keep the dual-DNS routing semantics: LAN DNS destinations remain directly
reachable, the external DNS service follows its separate upstream path, and
its source traffic must not recurse through the main DNS interception path.
A test CT at a different address cannot validate the final path while the DNS
service still uses the old production gateway.

Separately measure same-subnet layer-2 traffic, routed direct traffic, application
traffic, optional network traffic, and idle/load CPU and memory. No N100
throughput result is claimed. **QEMU remains deferred.**

## Maintenance and rollback

Commit or preserve working-tree changes before running:

```bash
bash n100-lxc/scripts/upgrade-stable.sh
```

The upgrade helper selects a formal stable release and creates a separate
upgrade branch/worktree. Review refreshed feeds, package providers, compiler
versions, input checksums and app compatibility before rebuilding. Development
`main` is not merged into production automatically.

Keep the old template, configuration, locks, and CT backup. Validate a new
test CT before any production address cutover. Roll back with the previous CT
or backup. Disk-firmware upgrade procedures are not a validated CT upgrade
path. Base-package upgrades may overwrite LXC adaptations; custom package
upgrades must retain compatibility patches. Repeat host acceptance after a
PVE kernel change.
