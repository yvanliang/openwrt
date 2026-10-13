export PROJECT_ROOT=/data/disk2/lyy_dataset/openwrt
export PATH="$PROJECT_ROOT/work/tools/bin:/usr/bin:/bin"
export TMPDIR="$PROJECT_ROOT/work/tmp"
export TMP="$TMPDIR" TEMP="$TMPDIR"
export GOTMPDIR="$TMPDIR"
export XDG_CACHE_HOME="$PROJECT_ROOT/cache/xdg"
export CCACHE_DIR="$PROJECT_ROOT/cache/ccache"
export GOCACHE="$PROJECT_ROOT/cache/go/build"
export GOPATH="$PROJECT_ROOT/cache/go/path"
export GOMODCACHE="$PROJECT_ROOT/cache/go/mod"
export CARGO_HOME="$PROJECT_ROOT/cache/rust/cargo"
export RUSTUP_HOME="$PROJECT_ROOT/cache/rust/rustup"
export PYTHONNOUSERSITE=1
export PYTHONPYCACHEPREFIX="$PROJECT_ROOT/cache/python"
export LC_ALL=C.UTF-8
unset CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_PROMPT_MODIFIER CONDA_SHLVL LD_LIBRARY_PATH LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH PYTHONPATH PKG_CONFIG_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
export CC="$PROJECT_ROOT/work/tools/bin/gcc"
export CXX="$PROJECT_ROOT/work/tools/bin/g++"
export GOAMD64=v1
export GOTOOLCHAIN=local
export GOMAXPROCS=16
