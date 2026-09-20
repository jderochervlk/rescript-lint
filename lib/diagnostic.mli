type position = { line : int; column : int; byte_offset : int }
type range = { start : position; finish : position }

type t = {
  rule : string;
  message : string;
  filename : string;
  range : range;
  fixes : Text_edit.t list;
}

val render : t -> string
(** Lines and columns are one-based; columns count UTF-8 bytes. *)
