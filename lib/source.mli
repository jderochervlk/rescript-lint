type kind = Implementation | Interface
type t = { filename : string; text : string; kind : kind }

val kind_of_filename : string -> (kind, Lint_error.t) result
val read : string -> (t, Lint_error.t) result

val write : original:t -> string -> (unit, Lint_error.t) result
(** Atomically replace an unchanged regular file, preserving its permissions.
    Symlinks and multiply linked files are refused. *)
