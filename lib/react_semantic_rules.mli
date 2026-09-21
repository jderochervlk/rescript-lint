val rule_ids : string list

val check :
  ?context:Semantic_model.context ->
  source:Source.t ->
  Parser.t ->
  Diagnostic.t list
