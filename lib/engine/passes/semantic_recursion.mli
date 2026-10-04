val check :
  emit:(string -> string -> Location.t -> unit) ->
  boundary:(string -> string -> Location.t -> unit) ->
  Semantic_model.scope ->
  Asttypes.rec_flag ->
  Parsetree.value_binding list ->
  unit
