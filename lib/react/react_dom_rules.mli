val rule_ids : string list

val check :
  ?module_signatures:(string * Parsetree.signature) list ->
  source:Source.t ->
  Parser.t ->
  Diagnostic.t list
