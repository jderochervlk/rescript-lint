#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
cli_pid=
writer_pid=
cleanup() {
  for pid in "$cli_pid" "$writer_pid"; do
    if [[ -n "$pid" ]]; then
      kill -TERM "$pid" 2>/dev/null || true
      wait "$pid" || true
    fi
  done
  rm -rf "$root"
}
trap cleanup EXIT
mkfifo "$root/config.json"
printf 'Console.log("disabled")\n' >"$root/Main.res"

check_once() {
  local attempts=0
  # Supply exactly one config read. Reopening the FIFO would block: there is
  # no second writer. Bound the wait so duplicate decoding fails, not hangs.
  printf '{"rules":{"no-console":false}}\n' >"$root/config.json" &
  writer_pid=$!
  rescript-lint "$@" --config "$root/config.json" "$root/Main.res" \
    >"$root/out" 2>"$root/err" &
  cli_pid=$!
  while kill -0 "$cli_pid" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -eq 100 ]]; then
      printf 'CLI did not finish after a single configuration read.\n' >&2
      return 1
    fi
    sleep 0.05
  done
  wait "$cli_pid"
  cli_pid=
  wait "$writer_pid"
  writer_pid=
  test ! -s "$root/out"
  test ! -s "$root/err"
}

check_once
check_once --fix
printf 'Lint and fix decode configuration once per invocation.\n'
