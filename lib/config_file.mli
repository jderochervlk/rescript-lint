val decode :
  base:string ->
  Rule_config.t ->
  Yojson.Basic.t ->
  (Rule_config.t, string) result

val load : Rule_config.t -> string -> (Rule_config.t, string) result
