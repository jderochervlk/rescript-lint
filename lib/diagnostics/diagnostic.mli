type position = { line : int; column : int; byte_offset : int }
type range = { start : position; finish : position }
type symbol_kind = Value | Module | Type
type symbol = { kind : symbol_kind; path : string }
type help = { message : string; url : string option }

type t = {
  rule : string;
  message : string;
  filename : string;
  range : range;
  fixes : Text_edit.t list;
  help : help option;
  symbol : symbol option;
}

val kind_name : symbol_kind -> string
val detail : t -> string

val render : t -> string
(** Lines and columns are one-based; columns count UTF-8 bytes. *)
