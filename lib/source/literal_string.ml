type t = string

let json_string raw =
  let input = "\"" ^ raw ^ "\"" in
  let lexer = Lexing.from_string input in
  try
    match Yojson.Basic.read_t (Yojson.init_lexer ()) lexer with
    | `String value
      when lexer.lex_abs_pos + lexer.lex_curr_pos = String.length input ->
        Some value
    | _ -> None
  with Yojson.Json_error _ -> None

let utf16 value =
  let buffer = Buffer.create (String.length value) in
  let rec loop offset =
    if offset = String.length value then Some (Buffer.contents buffer)
    else
      let decoded = String.get_utf_8_uchar value offset in
      if not (Uchar.utf_decode_is_valid decoded) then None
      else (
        Buffer.add_utf_16be_uchar buffer (Uchar.utf_decode_uchar decoded);
        loop (offset + Uchar.utf_decode_length decoded))
  in
  loop 0

let decode raw =
  let value = if String.contains raw '\\' then json_string raw else Some raw in
  Option.bind value utf16

let equal = String.equal
let compare = String.compare
