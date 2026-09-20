val of_positions :
  source:string -> Lexing.position -> Lexing.position -> Diagnostic.range

val of_location : source:string -> Location.t -> Diagnostic.range
val sort : Diagnostic.t list -> Diagnostic.t list
