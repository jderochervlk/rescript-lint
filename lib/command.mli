type t = Help | Version | Lint of string list | Fix of string list
type error = Missing_files | Unknown_option of string

val parse : string list -> (t, error) result
val error_message : error -> string
val help : string
val version : string
