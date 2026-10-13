#!/bin/sh
# Only child-shell resource limits are changed; no services are started.
set -eu
app=/usr/share/passwall2/app.sh
command=$(sed -n '/^[[:space:]]*ulimit /p' "$app")
[ "$command" = "$(printf '\tulimit -Sn 65535')" ]
inherited_soft=$(ulimit -Sn)
inherited_hard=$(ulimit -Hn)
echo "INFO: inherited nofile soft=$inherited_soft hard=$inherited_hard"
raised_soft=100000
case "$inherited_hard" in
  unlimited) ;;
  ''|*[!0-9]*)
    echo "FAIL: unexpected nofile hard limit: $inherited_hard" >&2
    exit 1
    ;;
  *)
    if [ "$inherited_hard" -le 65535 ]; then
      echo "FAIL: nofile regression needs a host hard limit above 65535; got $inherited_hard" >&2
      exit 1
    fi
    if [ "$inherited_hard" -lt "$raised_soft" ]; then
      raised_soft=$inherited_hard
    fi
    ;;
esac
# Never raise the host's hard limit or assume the PVE test value is available.
(
  ulimit -n 65535
  [ "$(ulimit -Sn)" = 65535 ]
  [ "$(ulimit -Hn)" = 65535 ]
  echo 'PASS: original command reproduces soft=65535 hard=65535'
)
eval "$command"
[ "$(ulimit -Sn)" = 65535 ]
[ "$(ulimit -Hn)" = "$inherited_hard" ]
/bin/sh -ec '
  test "$(ulimit -Sn)" = 65535
  test "$(ulimit -Hn)" = "$1"
  ulimit -Sn "$2"
  test "$(ulimit -Sn)" = "$2"
  test "$(ulimit -Hn)" = "$1"
' nofile-child "$inherited_hard" "$raised_soft"
echo "PASS: packaged Passwall2 preserves hard=$inherited_hard; child can raise soft=$raised_soft"
