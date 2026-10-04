open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)

let with_temp_channels use =
  let input_path = Filename.temp_file "rescript-lint-lsp-input" ".tmp" in
  let output_path = Filename.temp_file "rescript-lint-lsp-output" ".tmp" in
  Fun.protect
    ~finally:(fun () ->
      Sys.remove input_path;
      Sys.remove output_path)
    (fun () -> use input_path output_path)

let write_text path text =
  Out_channel.with_open_bin path (fun channel -> output_string channel text)

let round_trip =
  with_temp_channels (fun input_path output_path ->
      let packet =
        Jsonrpc.Notification.create ~method_:"initialized" ()
        |> fun notification -> Jsonrpc.Packet.Notification notification
      in
      let written =
        Out_channel.with_open_bin output_path (fun channel ->
            Lsp_transport.write channel packet)
      in
      let read =
        In_channel.with_open_bin output_path (fun channel ->
            Lsp_transport.read (Lsp_transport.create_input channel))
      in
      ignore input_path;
      written = Ok () && read = Ok (Some packet))

let read_text ?limits text =
  with_temp_channels (fun input_path output_path ->
      ignore output_path;
      write_text input_path text;
      In_channel.with_open_bin input_path (fun channel ->
          Lsp_transport.read (Lsp_transport.create_input ?limits channel)))

let closed_input =
  let path = Filename.temp_file "rescript-lint-lsp-closed" ".tmp" in
  Fun.protect
    ~finally:(fun () -> Sys.remove path)
    (fun () ->
      let channel = open_in_bin path in
      close_in channel;
      Lsp_transport.read (Lsp_transport.create_input channel))

let closed_output =
  let path = Filename.temp_file "rescript-lint-lsp-closed" ".tmp" in
  Fun.protect
    ~finally:(fun () -> Sys.remove path)
    (fun () ->
      let channel = open_out_bin path in
      close_out channel;
      let packet =
        Jsonrpc.Notification.create ~method_:"initialized" ()
        |> fun notification -> Jsonrpc.Packet.Notification notification
      in
      Lsp_transport.write channel packet)

let checks =
  [
    expect "round trips packet" round_trip;
    expect "accepts EOF" (read_text "" = Ok None);
    expect "rejects oversized header"
      (read_text
         ~limits:{ max_header_bytes = 8; max_message_bytes = 100 }
         "Content-Length: 2\r\n\r\n{}"
      = Error (Lsp_transport.Header_too_large { limit = 8 }));
    expect "rejects oversized message"
      (read_text
         ~limits:{ max_header_bytes = 100; max_message_bytes = 1 }
         "Content-Length: 2\r\n\r\n{}"
      = Error (Lsp_transport.Message_too_large { length = 2; limit = 1 }));
    expect "rejects negative message length"
      (read_text "Content-Length: -2\r\n\r\n"
      = Error
          (Lsp_transport.Message_too_large
             { length = -2; limit = 16 * 1024 * 1024 }));
    expect "rejects truncated header"
      (read_text "Content-Length: 2" = Error Lsp_transport.Unexpected_eof);
    expect "rejects truncated body"
      (match read_text "Content-Length: 2\r\n\r\n{" with
      | Error (Lsp_transport.Protocol_error _) -> true
      | Ok _ | Error _ -> false);
    expect "rejects malformed JSON"
      (match read_text "Content-Length: 2\r\n\r\n{x" with
      | Error (Lsp_transport.Protocol_error _) -> true
      | Ok _ | Error _ -> false);
    expect "rejects missing content length"
      (match read_text "\r\n" with
      | Error (Lsp_transport.Protocol_error _) -> true
      | Ok _ | Error _ -> false);
    expect "rejects invalid packet shape"
      (match read_text "Content-Length: 2\r\n\r\n{}" with
      | Error (Lsp_transport.Protocol_error _) -> true
      | Ok _ | Error _ -> false);
    expect "reports closed input"
      (match closed_input with
      | Error (Lsp_transport.Io_error _) -> true
      | Ok _ | Error _ -> false);
    expect "reports closed output"
      (match closed_output with
      | Error (Lsp_transport.Io_error _) -> true
      | Ok () | Error _ -> false);
    expect "renders oversized-message error"
      (Lsp_transport.render_error
         (Lsp_transport.Message_too_large { length = 2; limit = 1 })
      = "LSP message length 2 exceeds the 1-byte limit.");
    expect "renders oversized-header error"
      (Lsp_transport.render_error (Lsp_transport.Header_too_large { limit = 8 })
      = "LSP header exceeds the 8-byte limit.");
    expect "renders EOF error"
      (Lsp_transport.render_error Lsp_transport.Unexpected_eof
      = "Unexpected end of input while reading an LSP header.");
    expect "renders IO error"
      (Lsp_transport.render_error (Lsp_transport.Io_error "closed")
      = "LSP input/output error: closed");
    expect "renders protocol error"
      (Lsp_transport.render_error (Lsp_transport.Protocol_error "bad")
      = "Invalid LSP message: bad");
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
