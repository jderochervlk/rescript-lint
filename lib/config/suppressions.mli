val apply :
  known_rules:string list ->
  source:Source.t ->
  Parser.document ->
  Diagnostic.t list ->
  Diagnostic.t list
(** Apply ordinary-comment directives to successful lint-rule findings and
    append unsuppressible directive audit errors. Parse/analysis failures must
    bypass this boundary; non-rule diagnostics are also preserved defensively.
*)
