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
