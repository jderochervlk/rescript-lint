type t

val discover_files : roots:string list -> (string list, Lint_error.t) result
(** Validate explicit package roots and discover configuration/source inputs,
    without parsing source files. No implicit package resolution is performed.
*)

val load : roots:string list -> (t, Lint_error.t) result
val files : t -> string list

val scope :
  initial:Throws_scope.t ->
  project_modules:string list ->
  t ->
  (Throws_scope.t, Lint_error.t) result
(** Index packages in isolated declaration scopes, exposing only
    compiler-visible namespace roots. Project/dependency root collisions fail
    explicitly. *)
