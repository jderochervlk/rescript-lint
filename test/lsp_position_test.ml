open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)

let has_position index encoding byte_offset expected =
  Lsp_position.position index ~encoding ~byte_offset = Ok expected

let source = "a\195\169\240\159\152\128e\204\129\r\nx\n"
let index = Lsp_position.create source

let checks =
  let open Lsp_position in
  [
    expect "keeps source text" (text index = source);
    expect "UTF-8 ASCII" (has_position index Utf8 1 { line = 0; character = 1 });
    expect "UTF-8 BMP" (has_position index Utf8 3 { line = 0; character = 3 });
    expect "UTF-16 BMP" (has_position index Utf16 3 { line = 0; character = 2 });
    expect "UTF-8 astral"
      (has_position index Utf8 7 { line = 0; character = 7 });
    expect "UTF-16 astral"
      (has_position index Utf16 7 { line = 0; character = 4 });
    expect "UTF-16 combining mark"
      (has_position index Utf16 10 { line = 0; character = 6 });
    expect "CRLF carriage return"
      (has_position index Utf16 10 { line = 0; character = 6 });
    expect "CRLF line feed"
      (has_position index Utf16 11 { line = 0; character = 6 });
    expect "next line" (has_position index Utf16 12 { line = 1; character = 0 });
    expect "line end" (has_position index Utf16 13 { line = 1; character = 1 });
    expect "trailing empty line"
      (has_position index Utf16 14 { line = 2; character = 0 });
    expect "UTF-8 range"
      (range index ~encoding:Utf8 ~start_offset:3 ~finish_offset:7
      = Ok
          {
            start = { line = 0; character = 3 };
            finish = { line = 0; character = 7 };
          });
    expect "UTF-16 range across line ending"
      (range index ~encoding:Utf16 ~start_offset:10 ~finish_offset:12
      = Ok
          {
            start = { line = 0; character = 6 };
            finish = { line = 1; character = 0 };
          });
    expect "rejects middle of character"
      (Lsp_position.position index ~encoding:Utf16 ~byte_offset:2
      = Error (Offset_not_on_character_boundary { byte_offset = 2 }));
    expect "rejects negative offset"
      (Lsp_position.position index ~encoding:Utf8 ~byte_offset:(-1)
      = Error (Offset_out_of_bounds { byte_offset = -1; text_length = 14 }));
    expect "rejects offset after EOF"
      (Lsp_position.position index ~encoding:Utf8 ~byte_offset:15
      = Error (Offset_out_of_bounds { byte_offset = 15; text_length = 14 }));
    expect "rejects reversed range"
      (range index ~encoding:Utf8 ~start_offset:7 ~finish_offset:3
      = Error (Invalid_range { start_offset = 7; finish_offset = 3 }));
    expect "reports invalid UTF-8"
      (Lsp_position.position (create "\255") ~encoding:Utf16 ~byte_offset:1
      = Error (Invalid_utf8 { byte_offset = 0 }));
    expect "renders out-of-bounds error"
      (render_error (Offset_out_of_bounds { byte_offset = 2; text_length = 1 })
      = "Byte offset 2 is outside source text of length 1.");
    expect "renders character-boundary error"
      (render_error (Offset_not_on_character_boundary { byte_offset = 2 })
      = "Byte offset 2 is not on a UTF-8 character boundary.");
    expect "renders invalid UTF-8 error"
      (render_error (Invalid_utf8 { byte_offset = 2 })
      = "Source text contains invalid UTF-8 at byte offset 2.");
    expect "renders invalid range error"
      (render_error (Invalid_range { start_offset = 7; finish_offset = 3 })
      = "Range start 7 is after range end 3.");
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
