type kind = Implementation | Interface
type t = { filename : string; text : string; kind : kind }

val read : string -> (t, Lint_error.t) result
