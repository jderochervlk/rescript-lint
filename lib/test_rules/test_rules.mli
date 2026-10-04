val rule_ids : string list

val check :
  ?max_nested_describe:int ->
  ?module_signatures:(string * Parsetree.signature) list ->
  source:Source.t ->
  Parser.t ->
  Diagnostic.t list
(** Call only after explicitly selecting the rescript-vitest 3.0.1 adapter. *)
