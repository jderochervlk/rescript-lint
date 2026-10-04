type t =
  | Read_error of { filename : string; detail : string }
  | Write_error of { filename : string; detail : string }
  | Fix_error of { filename : string; detail : string }
  | Unsupported_file of string
  | Parse_errors of Diagnostic.t * Diagnostic.t list
  | Analysis_errors of Diagnostic.t * Diagnostic.t list

val diagnostics : t -> Diagnostic.t list option
(** Returns diagnostics carried by parse and analysis failures. *)

val render : t -> string
