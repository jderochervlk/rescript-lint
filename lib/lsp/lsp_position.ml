type encoding = Utf8 | Utf16
type position = { line : int; character : int }
type range = { start : position; finish : position }

type error =
  | Offset_out_of_bounds of { byte_offset : int; text_length : int }
  | Offset_not_on_character_boundary of { byte_offset : int }
  | Invalid_utf8 of { byte_offset : int }
  | Invalid_range of { start_offset : int; finish_offset : int }

type line = { start_offset : int; content_end_offset : int }
type t = { text : string; lines : line array }

let rec collect_lines text text_length start_offset cursor lines =
  if cursor = text_length then
    List.rev ({ start_offset; content_end_offset = cursor } :: lines)
  else if text.[cursor] = '\n' then
    let content_end_offset =
      if cursor > start_offset && text.[cursor - 1] = '\r' then cursor - 1
      else cursor
    in
    collect_lines text text_length (cursor + 1) (cursor + 1)
      ({ start_offset; content_end_offset } :: lines)
  else collect_lines text text_length start_offset (cursor + 1) lines

let create text =
  let text_length = String.length text in
  let lines = collect_lines text text_length 0 0 [] |> Array.of_list in
  { text; lines }

let text index = index.text

let line_for_offset lines byte_offset =
  let rec search lower upper =
    if lower > upper then upper
    else
      let middle = lower + ((upper - lower) / 2) in
      if lines.(middle).start_offset <= byte_offset then
        search (middle + 1) upper
      else search lower (middle - 1)
  in
  search 0 (Array.length lines - 1)

let code_units encoding decoded =
  match encoding with
  | Utf8 -> Uchar.utf_decode_length decoded
  | Utf16 -> Uchar.utf_16_byte_length (Uchar.utf_decode_uchar decoded) / 2

let character index encoding line byte_offset =
  let finish_offset = min byte_offset line.content_end_offset in
  let rec count cursor units =
    if cursor = finish_offset then Ok units
    else
      let decoded = String.get_utf_8_uchar index.text cursor in
      if not (Uchar.utf_decode_is_valid decoded) then
        Error (Invalid_utf8 { byte_offset = cursor })
      else
        let next = cursor + Uchar.utf_decode_length decoded in
        if next > finish_offset then
          Error (Offset_not_on_character_boundary { byte_offset })
        else count next (units + code_units encoding decoded)
  in
  count line.start_offset 0

let position index ~encoding ~byte_offset =
  let text_length = String.length index.text in
  if byte_offset < 0 || byte_offset > text_length then
    Error (Offset_out_of_bounds { byte_offset; text_length })
  else
    let line_number = line_for_offset index.lines byte_offset in
    let line = index.lines.(line_number) in
    Result.map
      (fun character -> { line = line_number; character })
      (character index encoding line byte_offset)

let range index ~encoding ~start_offset ~finish_offset =
  if start_offset > finish_offset then
    Error (Invalid_range { start_offset; finish_offset })
  else
    Result.bind (position index ~encoding ~byte_offset:start_offset)
      (fun start ->
        Result.map
          (fun finish -> { start; finish })
          (position index ~encoding ~byte_offset:finish_offset))

let render_error = function
  | Offset_out_of_bounds { byte_offset; text_length } ->
      Printf.sprintf "Byte offset %d is outside source text of length %d."
        byte_offset text_length
  | Offset_not_on_character_boundary { byte_offset } ->
      Printf.sprintf "Byte offset %d is not on a UTF-8 character boundary."
        byte_offset
  | Invalid_utf8 { byte_offset } ->
      Printf.sprintf "Source text contains invalid UTF-8 at byte offset %d."
        byte_offset
  | Invalid_range { start_offset; finish_offset } ->
      Printf.sprintf "Range start %d is after range end %d." start_offset
        finish_offset
