val decode :
  base:string ->
  Rule_config.t ->
  Yojson.Basic.t ->
  (Rule_config.t, string) result
(** Apply configuration entries in order, preserving unspecified settings.
    Resolve relative paths against [base]; reject unknown and duplicate keys. *)

val load : Rule_config.t -> string -> (Rule_config.t, string) result
