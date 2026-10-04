#!/usr/bin/env bash
set -euo pipefail

root=$(mktemp -d)
watch_pid=
cleanup() {
  if [[ -n "$watch_pid" ]]; then
    kill -TERM "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" || true
  fi
  rm -rf "$root"
}
trap cleanup EXIT
mkdir "$root/src"
printf '{}\n' >"$root/rescript.json"

wait_for() {
  local pattern=$1 file=$2 attempts=0
  until grep -q "$pattern" "$file" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -eq 100 ]]; then
      printf 'Timed out waiting for %s\n' "$pattern" >&2
      return 1
    fi
    sleep 0.05
  done
}

rescript-lint --watch --project "$root" >"$root/out" 2>"$root/err" &
watch_pid=$!
wait_for 'Watching 0 file' "$root/err"
printf 'Console.log("created")\n' >"$root/src/Added.res"
wait_for 'no-console' "$root/out"
printf '{\n' >"$root/rescript.json"
wait_for 'Cannot read file' "$root/err"
printf '{}\n' >"$root/rescript.json"
attempts=0
until [[ $(grep -c 'no-console' "$root/out") -ge 2 ]]; do
  attempts=$((attempts + 1))
  test "$attempts" -lt 100
  sleep 0.05
done
kill -TERM "$watch_pid"
set +e
wait "$watch_pid"
status=$?
set -e
watch_pid=
test "$status" -eq 143
printf 'Project watch discovers new files and recovers from configuration errors.\n'
