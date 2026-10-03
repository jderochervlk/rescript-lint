type request = { files : string list; rules : Rule_config.t }
type format = Human | Json
type watch = { files : string list; fix : bool; rules : Rule_config.t }

type t =
  | Help
  | Version
  | List_rules
  | Inspect_config of { filename : string; rules : Rule_config.t }
  | Lint of request
  | Fix of request
  | Watch of watch
  | Language_server of Rule_config.t

type error =
  | Missing_files
  | Unknown_option of string
  | Invalid_lsp_arguments
  | Invalid_inspect_arguments
  | Invalid_rule of string
  | Missing_rule of string
  | Missing_format
  | Invalid_format of string
  | Unsupported_format_mode

val parse : string list -> (t, error) result

val parse_with_format : string list -> format * (t, error) result
(** The last valid format before a format/missing-value error or [--] selects
    rendering, including rendering of command errors. *)

val error_message : error -> string
val help : string
val version : string
