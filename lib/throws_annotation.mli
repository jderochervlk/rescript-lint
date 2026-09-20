type t = Any | Named of string list list
type error = { location : Location.t; message : string }

val path : Longident.t -> string list option
val is_throws : Parsetree.attribute -> bool
val decode : Parsetree.attributes -> (t option, error) result
