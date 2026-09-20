(lang dune 3.24)
(name rescript_linter)
(version 0.1.0-dev)
(authors "Josh Vlk")
(maintainers "Josh Vlk <josh@vlkpack.com>")
(generate_opam_files true)
(cram enable)

(package
 (name rescript_linter)
 (synopsis "A linter for ReScript")
 (description "OCaml command-line tooling for ReScript lint rules.")
 (depends
  (ocaml (= 5.5.0))
  (dune (= 3.24.2))
  (cppo (and :build (= 1.8.0)))
  (flow_parser (= 0.267.0))
  (ocamlformat (and :with-dev-setup (= 0.29.0)))))
