type t =
  | Read_error of { filename : string; detail : string }
  | Unsupported_file of string
  | Parse_errors of Diagnostic.t * Diagnostic.t list

val render : t -> string
