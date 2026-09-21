val canonical_aliases : (string * string) list -> (string * string) list
(** Canonicalize connected declaration identities independently of package
    order. *)

val declarations :
  ?scope:Throws_scope.t ->
  Project_files.t ->
  (Throws_scope.t, Lint_error.t) result
(** Index all public declarations against an explicit imported scope, including
    implementation/interface exception identities. Provider metadata failures
    are returned before exposing any package contracts. *)

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
