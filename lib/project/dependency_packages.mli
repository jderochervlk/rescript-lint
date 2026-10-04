type t

type package = {
  name : string;
  dependencies : string list;
  namespace : string option;
  project : Project_files.t;
}

type option_context = Throws_dependencies | Source_root_dependencies

val discover_files :
  context:option_context ->
  roots:string list ->
  (string list, Lint_error.t) result
(** Discover configuration and source inputs without parsing sources. Only
    explicitly configured package roots are considered. *)

val load :
  context:option_context -> roots:string list -> (t, Lint_error.t) result

val files : t -> string list

val validate_exports :
  project_modules:string list -> t -> (package list, Lint_error.t) result
(** Expose parsed packages after checking public module-root collisions. The
    consuming analysis validates dependency cycles. *)

val validate :
  project_modules:string list -> t -> (package list, Lint_error.t) result
(** Check public module-root collisions and dependency cycles. *)
