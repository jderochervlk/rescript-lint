type watch = { files : string list; fix : bool }

type t =
  | Help
  | Version
  | Lint of string list
  | Fix of string list
  | Watch of watch
  | Language_server

type error = Missing_files | Unknown_option of string | Invalid_lsp_arguments

val parse : string list -> (t, error) result
val error_message : error -> string
val help : string
val version : string
