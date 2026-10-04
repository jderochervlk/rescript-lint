#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

opam exec -- dune build --profile release @install
npm run prepare:licenses
npm run pack:native
npm run test:package
