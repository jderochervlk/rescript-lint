type error =
  | Already_open of { uri : string }
  | Not_open of { uri : string }
  | Update_rejected of { uri : string; reason : Lsp_document.update_error }

type t

val empty : t
val count : t -> int
val find : uri:string -> t -> Lsp_document.t option
val open_document : Lsp_document.t -> t -> (t, error) result

val change :
  uri:string ->
  version:int ->
  text:string ->
  t ->
  (Lsp_document.t * t, error) result

val close : uri:string -> t -> (Lsp_document.t * t, error) result
val render_error : error -> string
