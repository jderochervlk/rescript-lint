val rule_ids : string list
val operator : source:Source.t -> Parsetree.expression -> string option
val check : source:Source.t -> Parser.t -> Diagnostic.t list
