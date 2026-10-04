type input = {
  uri : string;
  path : string;
  language_id : string;
  version : int;
  text : string;
}

type update_error =
  | Version_not_newer of { current_version : int; received_version : int }

type t

val create : input -> (t, Lint_error.t) result
val update : version:int -> text:string -> t -> (t, update_error) result
val uri : t -> string
val language_id : t -> string
val version : t -> int
val source : t -> Source.t
val positions : t -> Lsp_position.t
val render_update_error : update_error -> string
