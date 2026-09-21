type unit_ = {
  name : string;
  source : Source.t;
  tree : Parser.t;
  modified : float;
}

type t = { root : string; units : unit_ list }

val module_name : string -> string

val discover :
  root:string -> excluded:string list -> (string list, Lint_error.t) result

val load :
  ?overlay:Source.t ->
  ?parse:(Source.t -> (Parser.t, Lint_error.t) result) ->
  root:string ->
  excluded:string list ->
  unit ->
  (t, Lint_error.t) result
(** Discovery and source reads always run. The optional parser is an explicit
    boundary for content-validated parse reuse. *)

val signature : t -> string -> Parsetree.signature option
val signatures : t -> (string list * Parsetree.signature) list
val has_interface : t -> unit_ -> bool
val canonical : string -> string
