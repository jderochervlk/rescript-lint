val check :
  ?scope:Throws_scope.t ->
  source:Source.t ->
  Parser.t ->
  (Diagnostic.t list, Lint_error.t) result
(** Enforces annotations in the supplied scope. Without a scope, activation is
    source-local; an explicit project scope activates unannotated callers too.
    Unsupported active analysis fails explicitly. *)

val has_annotations : Parser.t -> bool

val exports :
  scope:Throws_scope.t ->
  source:Source.t ->
  Parser.t ->
  Throws_scope.t * Diagnostic.t list
