type request = { files : string list; rules : Rule_config.t }
type watch = { files : string list; fix : bool; rules : Rule_config.t }

type t =
  | Help
  | Version
  | List_rules
  | Lint of request
  | Fix of request
  | Watch of watch
  | Language_server of Rule_config.t

type error =
  | Missing_files
  | Unknown_option of string
  | Invalid_lsp_arguments
  | Invalid_rule of string
  | Missing_rule of string

val parse : string list -> (t, error) result
val error_message : error -> string
val help : string
val version : string
