let rec byte_offset source offset remaining =
  if remaining <= 0 || offset >= String.length source || source.[offset] = '\n'
  then offset
  else
    let decoded = String.get_utf_8_uchar source offset in
    let units = Uchar.utf_16_byte_length (Uchar.utf_decode_uchar decoded) / 2 in
    byte_offset source
      (offset + Uchar.utf_decode_length decoded)
      (remaining - units)

let position ~source (position : Lexing.position) =
  (* ReScript stores a byte offset for pos_bol but UTF-16 units for the column. *)
  let offset =
    byte_offset source position.pos_bol (position.pos_cnum - position.pos_bol)
  in
  Diagnostic.
    {
      line = position.pos_lnum;
      column = offset - position.pos_bol + 1;
      byte_offset = offset;
    }

let of_positions ~source start finish =
  Diagnostic.
    { start = position ~source start; finish = position ~source finish }

let of_location ~source (location : Location.t) =
  of_positions ~source location.loc_start location.loc_end

let sort =
  List.stable_sort (fun (left : Diagnostic.t) (right : Diagnostic.t) ->
      Int.compare left.range.start.byte_offset right.range.start.byte_offset)
