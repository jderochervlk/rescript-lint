type entry
type t

val empty : t
val is_empty : t -> bool
val decode : Yojson.Basic.t -> (t, string) result
val encode : t -> Yojson.Basic.t

val matching :
  legacy:string list ->
  t ->
  kind:Diagnostic.symbol_kind ->
  path:string ->
  entry option

val guidance : entry -> Diagnostic.help option
