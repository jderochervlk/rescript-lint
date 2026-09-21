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
  root:string ->
  excluded:string list ->
  unit ->
  (t, Lint_error.t) result

val signature : t -> string -> Parsetree.signature option
val signatures : t -> (string list * Parsetree.signature) list
val has_interface : t -> unit_ -> bool
val canonical : string -> string
