val rule_ids : string list

val check :
  max_lines:int ->
  max_switch_cases:int ->
  source:Source.t ->
  Parser.t ->
  Diagnostic.t list
