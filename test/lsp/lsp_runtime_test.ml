open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)

let request id typed =
  Lsp.Client_request.to_jsonrpc_request typed ~id:(`Int id) |> fun request ->
  Jsonrpc.Packet.Request request

let notification typed =
  Lsp.Client_notification.to_jsonrpc typed |> fun notification ->
  Jsonrpc.Packet.Notification notification

let initialize =
  let capabilities = Lsp.Types.ClientCapabilities.create () in
  let params = Lsp.Types.InitializeParams.create ~capabilities () in
  request 1 (Lsp.Client_request.Initialize params)

let open_source =
  let uri = Lsp.Types.DocumentUri.of_string "file:///workspace/example.res" in
  let item =
    Lsp.Types.TextDocumentItem.create ~languageId:"rescript"
      ~text:"Console.log(1)" ~uri ~version:1
  in
  Lsp.Types.DidOpenTextDocumentParams.create ~textDocument:item |> fun params ->
  Lsp.Client_notification.TextDocumentDidOpen params |> notification

let lifecycle_packets =
  [
    initialize;
    open_source;
    request 2 Lsp.Client_request.Shutdown;
    notification Lsp.Client_notification.Exit;
  ]

let write_packets path packets =
  Out_channel.with_open_bin path (fun channel ->
      List.iter
        (fun packet ->
          match Lsp_transport.write channel packet with
          | Ok () -> ()
          | Error error -> failwith (Lsp_transport.render_error error))
        packets)

let read_packets path =
  In_channel.with_open_bin path (fun channel ->
      let input = Lsp_transport.create_input channel in
      let rec read reversed =
        match Lsp_transport.read input with
        | Ok (Some packet) -> read (packet :: reversed)
        | Ok None -> Ok (List.rev reversed)
        | Error error -> Error (Lsp_transport.render_error error)
      in
      read [])

let run ?(close_output = false) ?(close_error = false) write_input =
  let input_path = Filename.temp_file "rescript-lint-lsp-input" ".tmp" in
  let output_path = Filename.temp_file "rescript-lint-lsp-output" ".tmp" in
  let error_path = Filename.temp_file "rescript-lint-lsp-error" ".tmp" in
  Fun.protect
    ~finally:(fun () ->
      Sys.remove input_path;
      Sys.remove output_path;
      Sys.remove error_path)
    (fun () ->
      write_input input_path;
      let input = open_in_bin input_path in
      let output = open_out_bin output_path in
      let error = open_out_bin error_path in
      if close_output then close_out output;
      if close_error then close_out error;
      let exit_code =
        Lsp_runtime.run
          ~dependencies:{ lint = Linter.lint_source }
          { input; output; error }
      in
      close_in_noerr input;
      close_out_noerr output;
      close_out_noerr error;
      let output = In_channel.with_open_bin output_path In_channel.input_all in
      let errors = In_channel.with_open_bin error_path In_channel.input_all in
      (exit_code, output, errors))

let run_packets ?close_output ?close_error packets =
  run ?close_output ?close_error (fun path -> write_packets path packets)

let run_text text =
  run (fun path ->
      Out_channel.with_open_bin path (fun channel -> output_string channel text))

let transcript = run_packets lifecycle_packets

let checks =
  let exit_code, output_text, errors = transcript in
  let output =
    let path = Filename.temp_file "rescript-lint-lsp-output-read" ".tmp" in
    Fun.protect
      ~finally:(fun () -> Sys.remove path)
      (fun () ->
        Out_channel.with_open_bin path (fun channel ->
            output_string channel output_text);
        read_packets path)
  in
  [
    expect "clean lifecycle exits zero" (exit_code = 0);
    expect "keeps stderr empty" (errors = "");
    expect "writes initialize diagnostics and shutdown packets"
      (match output with
      | Ok
          [
            Jsonrpc.Packet.Response { id = `Int 1; result = Ok _ };
            Jsonrpc.Packet.Notification diagnostics;
            Jsonrpc.Packet.Response
              { id = `Int 2; result = Ok (`Null | `Assoc []) };
          ] ->
          diagnostics.method_ = "textDocument/publishDiagnostics"
      | Ok _ | Error _ -> false);
    expect "EOF before initialize exits one"
      (let code, output, errors = run_text "" in
       code = 1 && output = "" && errors = "");
    expect "EOF after initialize exits one"
      (let code, _, _ = run_packets [ initialize ] in
       code = 1);
    expect "EOF after shutdown exits zero"
      (let code, _, _ =
         run_packets [ initialize; request 2 Lsp.Client_request.Shutdown ]
       in
       code = 0);
    expect "logs pre-initialize notification"
      (let code, output, errors =
         run_packets
           [
             notification Lsp.Client_notification.Initialized;
             notification Lsp.Client_notification.Exit;
           ]
       in
       code = 1 && output = ""
       && errors = "Ignored notification before initialization.\n");
    expect "reports malformed transport input"
      (let code, output, errors = run_text "Content-Length: 2\r\n\r\n{x" in
       code = 1 && output = ""
       && String.starts_with ~prefix:"rescript-lint lsp: Invalid LSP message:"
            errors);
    expect "reports output failure"
      (let code, _, errors = run_packets ~close_output:true [ initialize ] in
       code = 1
       && String.starts_with
            ~prefix:"rescript-lint lsp: LSP input/output error:" errors);
    expect "survives closed error channel"
      (let code, _, errors =
         run_packets ~close_error:true
           [ notification Lsp.Client_notification.Initialized ]
       in
       code = 1 && errors = "");
    expect "continues after action-free notification"
      (let code, _, errors =
         run_packets
           [ initialize; notification Lsp.Client_notification.Initialized ]
       in
       code = 1 && errors = "");
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
