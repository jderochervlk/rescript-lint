type t

val normalize_path : platform:Path_boundary.platform -> string -> string
(** Produce a lexical matching key, not a filesystem path. Windows keys fold
    ASCII case and separators while retaining drive and UNC roots. *)

val decode :
  cwd:string ->
  base:string ->
  known_ids:string list ->
  Yojson.Basic.t ->
  (t list, string) result

val settings_for_file : filename:string -> t list -> (string * bool) list
(** Match filesystem-canonical paths, retaining missing suffixes for overlays.
    Relative filenames use the working directory captured when each config was
    decoded. Windows matching also folds ASCII case and native separators. *)

val matching_index : filename:string -> id:string -> t list -> int option
