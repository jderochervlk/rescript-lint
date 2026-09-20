.PHONY: build test check format coverage coverage-tools

build:
	opam exec -- dune build @all

test:
	opam exec -- dune runtest

check:
	opam exec -- dune build @all @fmt
	opam exec -- dune runtest

format:
	opam exec -- dune fmt

coverage-tools:
	opam pin add bisect_ppx git+https://github.com/aantron/bisect_ppx.git\#7061d643ff492b0045796357ee6917ded21fb1f0 --yes

coverage:
	bash scripts/coverage.sh
