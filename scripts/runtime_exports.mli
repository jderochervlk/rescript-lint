type entry = string list * bool * string list

val entries : (string * Rescript_linter.Parser.t) list -> entry list
(** Public module paths, opacity, and value names. Interfaces must be selected
    before calling this pure extractor. *)

val read : directory:string -> (entry list, Rescript_linter.Lint_error.t) result
(** Reads the pinned sources, preferring each module's interface. *)

val render : entry list -> string
(** Deterministic OCaml source for the checked-in runtime inventory. *)
