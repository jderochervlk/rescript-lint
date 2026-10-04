#!/usr/bin/env bash
set -euo pipefail

lint_command=${1:-rescript-lint}
root=$(mktemp -d "${TMPDIR:-/tmp}/rescript-runtime-throws-cli.XXXXXX")
trap 'rm -rf "$root"' EXIT
printf '%s\n' 'let value = JSON.parseOrThrow("{}")' > "$root/Main.res"

"$lint_command" "$root/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Runtime throws contracts remain opt-in.'

status=0
"$lint_command" --throws-runtime rescript-12.3.1 "$root/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 1 && ! -s "$root/err" ]]
grep -Fq "$root/Main.res:1:13: error [no-unhandled-throws]" "$root/out"
[[ $(grep -Fc '[no-unhandled-throws]' "$root/out") -eq 1 ]]
printf '%s\n' 'The pinned runtime adapter reports each unhandled JSON call once.'

printf '%s\n' '{"throwsRuntime":"rescript-12.3.1"}' > "$root/lint.json"
printf '%s\n' 'let value = try JSON.parseOrThrow("{}") catch {| _ => JSON.Null}' > "$root/Main.res"
"$lint_command" --config "$root/lint.json" "$root/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Configured runtime contracts accept catch-all handlers.'

printf '%s\n' 'Unknown.read()' > "$root/Main.res"
status=0
"$lint_command" --throws-runtime rescript-12.3.1 "$root/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 && ! -s "$root/out" ]]
grep -Fq '[throws-analysis]' "$root/err"
printf '%s\n' 'Explicit runtime analysis fails on unavailable callable metadata.'

"$lint_command" --throws-runtime rescript-12.3.1 --disable-rule no-unhandled-throws "$root/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Disabling the throws rule bypasses the runtime adapter.'

status=0
"$lint_command" --throws-runtime unsupported "$root/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 && ! -s "$root/out" && -s "$root/err" ]]
printf '%s\n' 'Unknown runtime adapter versions are rejected.'
