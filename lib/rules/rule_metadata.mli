type category =
  | Correctness
  | Suspicious
  | Pedantic
  | Perf
  | Style
  | Restriction

type t = { id : string; category : category; enabled_by_default : bool }

val category_name : category -> string
