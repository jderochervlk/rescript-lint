type snapshot
type dependencies = { observe : string list -> snapshot; sleep : unit -> unit }
type dynamic_dependencies = { snapshot : unit -> snapshot; wait : unit -> unit }

val observe : string list -> snapshot
val failed : files:string list -> string -> snapshot
val command_snapshot : string list -> snapshot

val observe_inputs :
  rules:Rule_config.t ->
  files:string list ->
  configuration:string list ->
  snapshot

val loop_dynamic :
  dependencies:dynamic_dependencies ->
  continue:(unit -> bool) ->
  on_change:(unit -> unit) ->
  refresh_after_change:bool ->
  initial:snapshot ->
  unit

val loop :
  dependencies:dependencies ->
  continue:(unit -> bool) ->
  on_change:(unit -> unit) ->
  refresh_after_change:bool ->
  files:string list ->
  initial:snapshot ->
  unit
