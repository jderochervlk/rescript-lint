type prepared
(** A fixed-point declaration index for one parsed project and imported scope.
    Rebuild after either input changes; this value does not cache or invalidate
    semantic analysis. Annotation errors are retained per module. *)

val prepare : ?scope:Throws_scope.t -> Project_files.t -> prepared
val annotation_errors : prepared -> (string * Diagnostic.t list) list

val active :
  ?scope:Throws_scope.t ->
  project:Project_files.t ->
  source:Source.t ->
  Parser.t ->
  bool
(** Determine caller activation without constructing the index. Public checking
    still prepares only active callers, at the existing point in the pipeline.
*)

val relevant_errors :
  source:Source.t -> Parser.t -> prepared -> Diagnostic.t list
(** Sorted errors from the caller's transitive project dependencies only. *)

val exported_scope : prepared -> (Throws_scope.t, Lint_error.t) result
(** Validate every declaration before exposing dependency contracts and
    exception aliases. Unlike caller checking, unrelated annotation errors also
    fail. *)

val check_prepared :
  source:Source.t ->
  Parser.t ->
  prepared ->
  (Diagnostic.t list, Lint_error.t) result
(** Derive activation and relevant errors for an implementation or interface. *)

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
