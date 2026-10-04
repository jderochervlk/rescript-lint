#!/usr/bin/env bash
set -euo pipefail

signal=$1
source_file=$2
stderr_file=$3
change_file=$4
fix_mode=$5

wait_for() {
  local pattern=$1
  local attempts=0
  until grep -q "$pattern" "$stderr_file" 2>/dev/null; do
    attempts=$((attempts + 1))
    if [[ $attempts -eq 100 ]]; then
      kill -TERM "$watch_pid"
      wait "$watch_pid" || true
      return 1
    fi
    sleep 0.05
  done
}

arguments=(--watch)
if [[ $fix_mode == yes ]]; then
  arguments+=(--fix)
fi

rescript-lint "${arguments[@]}" "$source_file" >watch.stdout 2>"$stderr_file" &
watch_pid=$!
wait_for "Watching 1 file"

if [[ $change_file == yes ]]; then
  touch "$source_file"
  wait_for "Change detected"
fi

kill -"$signal" "$watch_pid"
set +e
wait "$watch_pid"
status=$?
set -e

case "$signal" in
  INT) test "$status" -eq 130 ;;
  TERM) test "$status" -eq 143 ;;
  *) exit 2 ;;
esac
