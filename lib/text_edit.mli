type t = { start : int; finish : int; text : string }
type error = Invalid_range | Overlapping_edits

val apply : string -> t list -> (string, error) result
