type t
type semantic_package = { namespace : string option; project : Project_files.t }

val discover_files : roots:string list -> (string list, Lint_error.t) result
(** Validate explicit package roots and discover configuration/source inputs,
    without parsing source files. No implicit package resolution is performed.
*)

val load : roots:string list -> (t, Lint_error.t) result
val files : t -> string list

val semantic_packages :
  project_modules:string list ->
  t ->
  (semantic_package list, Lint_error.t) result
(** Validate public module collisions and the explicit dependency graph, then
    expose parsed package projects for source-derived semantic adapters. *)

val scope :
  initial:Throws_scope.t ->
  project_modules:string list ->
  t ->
  (Throws_scope.t, Lint_error.t) result
(** Index packages in isolated declaration scopes, exposing only
    compiler-visible namespace roots. Project/dependency root collisions fail
    explicitly. *)
