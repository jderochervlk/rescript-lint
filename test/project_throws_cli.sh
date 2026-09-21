#!/usr/bin/env bash
set -euo pipefail

lint_command=${1:-rescript-lint}
root=$(mktemp -d "${TMPDIR:-/tmp}/rescript-project-throws-cli.XXXXXX")
trap 'rm -rf "$root"' EXIT
mkdir "$root/src"
printf '%s\n' '{"sources":"src"}' > "$root/rescript.json"
printf '%s\n' 'exception Missing' '' '@throws(Missing)' 'let read = () => 0' > "$root/src/Api.res"
printf '%s\n' 'let value = Api.read()' > "$root/src/Main.res"

status=0
"$lint_command" --project "$root" "$root/src/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 1 && ! -s "$root/err" ]]
grep -Fq "$root/src/Main.res:1:13: error [no-unhandled-throws]" "$root/out"
printf '%s\n' 'Project mode checks imported throws contracts without local annotations.'

"$lint_command" "$root/src/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Source-only mode retains its local contract boundary.'

printf '%s\n' 'let value = try Api.read() catch {| Api.Missing => 0}' > "$root/src/Main.res"
printf '%s\n' '{"root":"."}' > "$root/lint.json"
"$lint_command" --config "$root/lint.json" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Configured project discovery accepts imported named exception handlers.'

printf '%s\n' '@throws(42)' 'let read = () => 0' > "$root/src/Api.res"
printf '%s\n' 'let value = Api.read()' > "$root/src/Main.res"
"$lint_command" --project "$root" --disable-rule no-unhandled-throws "$root/src/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Disabling throws analysis bypasses malformed imported contract metadata.'

status=0
"$lint_command" --project "$root" "$root/src/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 && ! -s "$root/out" ]]
grep -Fq "$root/src/Api.res:1:9: error [throws-analysis]" "$root/err"
printf '%s\n' 'Malformed imported metadata reports its provider location and analysis status.'

cp "$root/src/Main.res" "$root/original.res"
status=0
"$lint_command" --fix --project "$root" "$root/src/Main.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 && ! -s "$root/out" ]]
grep -Fq '[throws-analysis]' "$root/err"
cmp "$root/src/Main.res" "$root/original.res"
printf '%s\n' 'Fix mode leaves the caller unchanged when imported analysis fails.'

printf '%s\n' 'let read: unit => int' > "$root/src/Api.resi"
"$lint_command" --project "$root" "$root/src/Main.res" > "$root/out" 2> "$root/err"
[[ ! -s "$root/out" && ! -s "$root/err" ]]
printf '%s\n' 'Public interfaces take precedence over hidden implementation annotations.'
