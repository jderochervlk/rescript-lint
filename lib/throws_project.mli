val check :
  project:Project_files.t ->
  source:Source.t ->
  Parser.t ->
  (Diagnostic.t list, Lint_error.t) result
(** Resolve project declaration contracts before inspecting a caller. Interfaces
    define public contracts; unsupported metadata fails in its provider source.
*)
