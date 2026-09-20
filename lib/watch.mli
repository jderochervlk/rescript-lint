type snapshot
type dependencies = { observe : string list -> snapshot; sleep : unit -> unit }

val observe : string list -> snapshot

val loop :
  dependencies:dependencies ->
  continue:(unit -> bool) ->
  on_change:(unit -> unit) ->
  refresh_after_change:bool ->
  files:string list ->
  initial:snapshot ->
  unit
