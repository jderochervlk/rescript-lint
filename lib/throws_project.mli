val check :
  ?scope:Throws_scope.t ->
  project:Project_files.t ->
  source:Source.t ->
  Parser.t ->
  (Diagnostic.t list, Lint_error.t) result
(** Resolve project declaration contracts before inspecting a caller. An
    explicit scope supplies imported contracts and activates checking for every
    caller. Interfaces define public contracts; unsupported metadata fails in
    its provider source. *)
