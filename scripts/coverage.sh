#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p _coverage
coverage_run=$(mktemp -d "$PWD/_coverage/run.XXXXXX")

BISECT_FILE="$coverage_run/bisect" opam exec -- \
  dune runtest --force --instrument-with bisect_ppx

opam exec -- bisect-ppx-report summary --per-file \
  --expect lib/ --expect bin/ --coverage-path "$coverage_run" \
  | tee "$coverage_run/summary.txt"

opam exec -- bisect-ppx-report html \
  --expect lib/ --expect bin/ --coverage-path "$coverage_run" \
  -o "$coverage_run/html"

awk '
  $2 == "%" {
    rows++
    split($3, points, "/")
    if (points[2] > 0 && points[1] * 100 < points[2] * 90) {
      print "Coverage below 90%: " $0
      failed = 1
    }
  }
  END { exit (failed || rows < 2) }
' "$coverage_run/summary.txt"

printf 'Coverage report: %s/html/index.html\n' "$coverage_run"
