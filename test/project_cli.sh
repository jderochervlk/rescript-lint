#!/usr/bin/env bash
set -euo pipefail

lint_command=${1:-rescript-lint}
root=$(mktemp -d "${TMPDIR:-/tmp}/rescript-project-cli.XXXXXX")
trap 'rm -rf "$root"' EXIT
mkdir "$root/src"
printf '%s\n' '{"sources":"src"}' > "$root/rescript.json"
printf '%s\n' 'let value = <img />' > "$root/src/View.res"
printf '%s\n' '{"root":".","jsxRuntime":"react-dom","rules":{"jsx-a11y/alt-text":true}}' > "$root/lint.json"

status=0
"$lint_command" --config "$root/lint.json" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 1 && ! -s "$root/err" ]]
grep -Fq '[jsx-a11y/alt-text]' "$root/out"
printf '%s\n' 'Configuration discovers project sources and activates its adapter.'

"$lint_command" --config "$root/lint.json" --disable-rule jsx-a11y/alt-text > "$root/out"
[[ ! -s "$root/out" ]]
printf '%s\n' 'Later CLI selection overrides configured activation.'

status=0
"$lint_command" --enable-rule jsx-a11y/alt-text "$root/src/View.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 && ! -s "$root/out" ]]
grep -Fq '[adapter-analysis]' "$root/err"
printf '%s\n' 'Missing adapter exits with an explicit analysis error.'

printf '%s\n' '// rescript-lint-disable-next-line no-console -- expected output' 'Console.log(1)' > "$root/src/View.res"
"$lint_command" --fix "$root/src/View.res" > "$root/out"
[[ ! -s "$root/out" ]]
printf '%s\n' 'Fix mode preserves valid audited suppressions.'

printf '%s\n' '// rescript-lint-disable-next-line no-console' 'let value = 1' > "$root/src/View.res"
status=0
"$lint_command" "$root/src/View.res" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 1 && ! -s "$root/err" ]]
grep -Fq '[suppression]' "$root/out"
printf '%s\n' 'Unused suppressions remain hard lint findings.'

printf '%s\n' '{' > "$root/lint.json"
status=0
"$lint_command" --config "$root/lint.json" > "$root/out" 2> "$root/err" || status=$?
[[ $status -eq 2 ]]
grep -Fq 'Invalid configuration JSON' "$root/err"
printf '%s\n' 'Invalid configuration fails before linting.'
