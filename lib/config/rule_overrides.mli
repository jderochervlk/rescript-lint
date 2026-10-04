type t

val decode :
  cwd:string ->
  base:string ->
  known_ids:string list ->
  Yojson.Basic.t ->
  (t list, string) result

val settings_for_file : filename:string -> t list -> (string * bool) list
(** Match lexical absolute paths without filesystem reads. Relative filenames
    use the working directory captured when each config was decoded. *)

val matching_index : filename:string -> id:string -> t list -> int option
