#!/usr/bin/env bash
set -euo pipefail

lint_command=${1:-rescript-lint}
work_directory=$(mktemp -d "${TMPDIR:-/tmp}/rescript-rule-modes.XXXXXX")
watch_pid=

cleanup() {
  if [[ -n $watch_pid ]]; then
    kill -TERM "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" 2>/dev/null || true
  fi
  rm -rf "$work_directory"
}
trap cleanup EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

frame() {
  printf 'Content-Length: %d\r\n\r\n%s' "${#1}" "$1"
}

lsp_messages() {
  frame '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
  frame '{"jsonrpc":"2.0","method":"initialized","params":{}}'
  frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///__rescript_linter_unsaved_rule_modes__.res","languageId":"rescript","version":1,"text":"let idle = () => ()"}}}'
  frame '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///__rescript_linter_unsaved_rule_modes__.res","version":2},"contentChanges":[{"text":"let idle = () => 1"}]}}'
  frame '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///__rescript_linter_unsaved_rule_modes__.res","version":3},"contentChanges":[{"text":"let idle = () => ()"}]}}'
  frame '{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
  frame '{"jsonrpc":"2.0","method":"exit"}'
}

check_lsp() {
  local output header separator length body version=0 publications=0
  output=$(lsp_messages | "$lint_command" lsp --stdio --enable-rule no-empty-function)
  while IFS= read -r header; do
    [[ -z $header ]] && continue
    header=${header%$'\r'}
    [[ $header == 'Content-Length: '* ]] || fail "Unexpected LSP header: $header"
    length=${header#Content-Length: }
    while IFS= read -r separator && [[ $separator != $'\r' ]]; do
      [[ $separator == 'Content-Type: '* ]] || fail "Unexpected LSP header: $separator"
    done
    [[ $separator == $'\r' ]] || fail 'Missing LSP frame separator'
    IFS= read -r -N "$length" body || fail 'Truncated LSP body'
    if [[ $body == *'"method":"textDocument/publishDiagnostics"'* ]]; then
      publications=$((publications + 1))
      version=$((version + 1))
      [[ $body == *"\"version\":$version"* ]] || fail 'Unexpected diagnostic version'
      if [[ $version -eq 2 ]]; then
        [[ $body == *'"diagnostics":[]'* ]] || fail 'Changed unsaved text did not clear diagnostics'
      else
        [[ $body == *'"code":"no-empty-function"'* ]] || fail 'Enabled optional rule missing from LSP diagnostics'
      fi
    fi
  done <<< "$output"
  [[ $publications -eq 3 ]] || fail "Expected three diagnostic publications, got $publications"
  printf '%s\n' 'LSP optional rule survives unsaved document changes.'
}

wait_for() {
  local output_file=$1 pattern=$2 attempts=0
  until grep -Fq "$pattern" "$output_file"; do
    kill -0 "$watch_pid" 2>/dev/null || fail 'Watcher exited before the expected output'
    attempts=$((attempts + 1))
    [[ $attempts -lt 100 ]] || fail "Timed out waiting for: $pattern"
    sleep 0.05
  done
}

check_watch() {
  local mode=$1 source_file="$work_directory/$1.res"
  local stdout_file="$work_directory/$1.out" stderr_file="$work_directory/$1.err"
  local arguments=(--watch --enable-rule no-empty-function)
  local status=0
  if [[ $mode == fix ]]; then
    arguments+=(--fix)
  fi
  printf 'let idle = () => ()\n' > "$source_file"
  "$lint_command" "${arguments[@]}" "$source_file" > "$stdout_file" 2> "$stderr_file" &
  watch_pid=$!
  wait_for "$stderr_file" 'Watching 1 file(s).'
  wait_for "$stdout_file" "$source_file:1:12: error [no-empty-function]"
  printf '// changed unsaved buffer persisted to disk\nlet idle = () => ()\n' > "$source_file.next"
  mv "$source_file.next" "$source_file"
  wait_for "$stderr_file" 'Change detected. Re-running lint.'
  wait_for "$stdout_file" "$source_file:2:12: error [no-empty-function]"
  kill -TERM "$watch_pid"
  wait "$watch_pid" || status=$?
  watch_pid=
  [[ $status -eq 143 ]] || fail "Unexpected watcher exit status: $status"
  printf 'Watch %s retains the optional rule after a file change.\n' "$mode"
}

check_lsp
check_watch lint
check_watch fix
