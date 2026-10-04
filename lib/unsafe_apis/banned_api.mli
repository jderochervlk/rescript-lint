type rule = { id : string; message : string list -> string option }

val check :
  ?context:Semantic_model.context ->
  rules:rule list ->
  source:Source.t ->
  Parser.t ->
  Diagnostic.t list
(** Resolves known runtime references through lexical module aliases and opens.
    Captured value aliases are reported only at capture. Unknown module contents
    are not guessed; findings use canonical API messages and source ranges. *)
