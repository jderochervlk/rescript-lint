.PHONY: build test check lint lint-run format coverage coverage-tools

build:
	opam exec -- dune build @all

test:
	opam exec -- dune runtest

check:
	opam exec -- dune build @all @check @fmt
	$(MAKE) lint-run
	opam exec -- dune runtest

lint:
	opam exec -- dune build @check scripts/lint/artifact_manifest.exe
	$(MAKE) lint-run

lint-run:
	opam exec -- node --test test/lint/adapter.test.mjs
	opam exec -- node scripts/lint/cli.mjs

format:
	opam exec -- dune fmt

coverage-tools:
	opam pin add bisect_ppx git+https://github.com/aantron/bisect_ppx.git\#7061d643ff492b0045796357ee6917ded21fb1f0 --yes

coverage:
	bash scripts/coverage.sh
