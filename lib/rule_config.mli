type rule = { id : string; enabled_by_default : bool }
type t

val rules : rule list
val default : t
val enabled : t -> string -> bool
val set : t -> id:string -> enabled:bool -> (t, string) result
val listing : string
val options : t -> Project_options.t
val with_options : Project_options.t -> t -> t
val enabled_ids : t -> string list

val for_file : filename:string -> t -> t
(** Resolve ordered per-file rule settings from the unchanged base rules. Global
    project and adapter options remain unchanged. *)

val with_overrides : base:string -> t -> Yojson.Basic.t -> (t, string) result
(** Replace configured overrides, anchored to the defining config directory. An
    empty array clears overrides. *)
