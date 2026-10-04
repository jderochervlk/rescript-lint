open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)
let dependencies = Lsp_server.{ lint = Linter.lint_source }
let uri = Lsp.Types.DocumentUri.of_string "file:///workspace/example.res"

let request id typed =
  Lsp.Client_request.to_jsonrpc_request typed ~id:(`Int id) |> fun request ->
  Jsonrpc.Packet.Request request

let notification typed =
  Lsp.Client_notification.to_jsonrpc typed |> fun notification ->
  Jsonrpc.Packet.Notification notification

let initialize encodings =
  let general =
    Lsp.Types.GeneralClientCapabilities.create ~positionEncodings:encodings ()
  in
  let capabilities = Lsp.Types.ClientCapabilities.create ~general () in
  let params = Lsp.Types.InitializeParams.create ~capabilities () in
  request 1 (Lsp.Client_request.Initialize params)

let open_source text version =
  let item =
    Lsp.Types.TextDocumentItem.create ~languageId:"rescript" ~text ~uri ~version
  in
  Lsp.Types.DidOpenTextDocumentParams.create ~textDocument:item |> fun params ->
  Lsp.Client_notification.TextDocumentDidOpen params |> notification

let change_source text version =
  let document =
    Lsp.Types.VersionedTextDocumentIdentifier.create ~uri ~version
  in
  let change = Lsp.Types.TextDocumentContentChangeEvent.create ~text () in
  Lsp.Types.DidChangeTextDocumentParams.create ~contentChanges:[ change ]
    ~textDocument:document
  |> fun params ->
  Lsp.Client_notification.TextDocumentDidChange params |> notification

let close_source =
  let document = Lsp.Types.TextDocumentIdentifier.create ~uri in
  Lsp.Types.DidCloseTextDocumentParams.create ~textDocument:document
  |> fun params ->
  Lsp.Client_notification.TextDocumentDidClose params |> notification

let publish = function
  | Lsp_server.Send (Jsonrpc.Packet.Notification notification) -> (
      match Lsp.Server_notification.of_jsonrpc notification with
      | Ok (Lsp.Server_notification.PublishDiagnostics params) -> Some params
      | Ok _ | Error _ -> None)
  | Lsp_server.Send _ | Lsp_server.Log _ | Lsp_server.Exit _ -> None

let published effects = List.find_map publish effects

let has_error code = function
  | [
      Lsp_server.Send
        (Jsonrpc.Packet.Response { result = Error { code = actual; _ }; _ });
    ] ->
      actual = code
  | _ -> false

let open_at target text version =
  let item =
    Lsp.Types.TextDocumentItem.create ~languageId:"rescript" ~text ~uri:target
      ~version
  in
  Lsp.Types.DidOpenTextDocumentParams.create ~textDocument:item |> fun params ->
  Lsp.Client_notification.TextDocumentDidOpen params |> notification

let empty_change version =
  let document =
    Lsp.Types.VersionedTextDocumentIdentifier.create ~uri ~version
  in
  Lsp.Types.DidChangeTextDocumentParams.create ~contentChanges:[]
    ~textDocument:document
  |> fun params ->
  Lsp.Client_notification.TextDocumentDidChange params |> notification

let initialized encoding =
  Lsp_server.handle ~dependencies Lsp_server.initial (initialize encoding)

let utf8_state, utf8_initialize_effects =
  initialized
    [
      Lsp.Types.PositionEncodingKind.UTF16; Lsp.Types.PositionEncodingKind.UTF8;
    ]

let utf16_state, _ = initialized [ Lsp.Types.PositionEncodingKind.UTF16 ]

let open_state, open_effects =
  Lsp_server.handle ~dependencies utf8_state (open_source "Console.log(1)" 1)

let changed_state, change_effects =
  Lsp_server.handle ~dependencies open_state (change_source "let clean = 1" 2)

let closed_state, close_effects =
  Lsp_server.handle ~dependencies changed_state close_source

let checks =
  [
    expect "initial state"
      (Lsp_server.lifecycle Lsp_server.initial
      = Lsp_server.Waiting_for_initialize);
    expect "negotiates UTF-8"
      (Lsp_server.lifecycle utf8_state = Running
      && Lsp_server.encoding utf8_state = Utf8);
    expect "falls back to UTF-16" (Lsp_server.encoding utf16_state = Utf16);
    expect "responds to initialize"
      (match utf8_initialize_effects with
      | [ Send (Jsonrpc.Packet.Response { result = Ok _; _ }) ] -> true
      | _ -> false);
    expect "opens and stores document"
      (match
         Lsp_server.document
           ~uri:(Lsp.Types.DocumentUri.to_string uri)
           open_state
       with
      | Some document -> Lsp_document.version document = 1
      | None -> false);
    expect "publishes lint finding"
      (match published open_effects with
      | Some { diagnostics = [ diagnostic ]; version = Some 1; _ } ->
          diagnostic.code = Some (`String "no-console")
      | Some _ | None -> false);
    expect "publishes clean change"
      (match published change_effects with
      | Some { diagnostics = []; version = Some 2; _ } -> true
      | Some _ | None -> false);
    expect "updates stored version"
      (match
         Lsp_server.document
           ~uri:(Lsp.Types.DocumentUri.to_string uri)
           changed_state
       with
      | Some document -> Lsp_document.version document = 2
      | None -> false);
    expect "ignores stale change"
      (match
         Lsp_server.handle ~dependencies changed_state
           (change_source "Console.log(1)" 1)
       with
      | unchanged, [ Log _ ] -> unchanged == changed_state
      | _ -> false);
    expect "close clears diagnostics"
      (match published close_effects with
      | Some { diagnostics = []; version = Some 2; _ } -> true
      | Some _ | None -> false);
    expect "close removes document"
      (Lsp_server.document
         ~uri:(Lsp.Types.DocumentUri.to_string uri)
         closed_state
      = None);
    expect "publishes parse errors"
      (let _, effects =
         Lsp_server.handle ~dependencies utf16_state (open_source "let =" 1)
       in
       match published effects with
       | Some { diagnostics = _ :: _; _ } -> true
       | Some _ | None -> false);
    expect "shutdown then exit is clean"
      (let shutdown_state, shutdown_effects =
         Lsp_server.handle ~dependencies utf16_state
           (request 2 Lsp.Client_request.Shutdown)
       in
       let stopped, exit_effects =
         Lsp_server.handle ~dependencies shutdown_state
           (notification Lsp.Client_notification.Exit)
       in
       Lsp_server.lifecycle shutdown_state = Shutdown_requested
       && Lsp_server.lifecycle stopped = Stopped
       && (match shutdown_effects with [ Send _ ] -> true | _ -> false)
       && exit_effects = [ Exit 0 ]);
    expect "exit without shutdown fails"
      (let stopped, effects =
         Lsp_server.handle ~dependencies utf16_state
           (notification Lsp.Client_notification.Exit)
       in
       Lsp_server.lifecycle stopped = Stopped && effects = [ Exit 1 ]);
    expect "unsupported request returns method-not-found"
      (let unknown =
         Jsonrpc.Request.create ~id:(`Int 3) ~method_:"custom/unknown" ()
       in
       match
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Request unknown)
       with
       | ( _,
           [
             Send
               (Jsonrpc.Packet.Response
                  {
                    result =
                      Error
                        { code = Jsonrpc.Response.Error.Code.MethodNotFound; _ };
                    _;
                  });
           ] ) ->
           true
       | _ -> false);
    expect "rejects duplicate initialize"
      (let _, actions =
         Lsp_server.handle ~dependencies utf16_state
           (initialize [ Lsp.Types.PositionEncodingKind.UTF16 ])
       in
       has_error Jsonrpc.Response.Error.Code.InvalidRequest actions);
    expect "rejects shutdown before initialize"
      (let _, actions =
         Lsp_server.handle ~dependencies Lsp_server.initial
           (request 5 Lsp.Client_request.Shutdown)
       in
       has_error Jsonrpc.Response.Error.Code.ServerNotInitialized actions);
    expect "rejects duplicate shutdown"
      (let shutdown_state, _ =
         Lsp_server.handle ~dependencies utf16_state
           (request 6 Lsp.Client_request.Shutdown)
       in
       let _, actions =
         Lsp_server.handle ~dependencies shutdown_state
           (request 7 Lsp.Client_request.Shutdown)
       in
       has_error Jsonrpc.Response.Error.Code.InvalidRequest actions);
    expect "rejects invalid known request parameters"
      (let invalid =
         Jsonrpc.Request.create ~id:(`Int 8) ~method_:"textDocument/hover" ()
       in
       let _, actions =
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Request invalid)
       in
       has_error Jsonrpc.Response.Error.Code.InvalidParams actions);
    expect "rejects request before initialize"
      (let unknown =
         Jsonrpc.Request.create ~id:(`Int 9) ~method_:"custom/unknown" ()
       in
       let _, actions =
         Lsp_server.handle ~dependencies Lsp_server.initial
           (Jsonrpc.Packet.Request unknown)
       in
       has_error Jsonrpc.Response.Error.Code.ServerNotInitialized actions);
    expect "rejects supported-shape unimplemented request"
      (let text_document = Lsp.Types.TextDocumentIdentifier.create ~uri in
       let position = Lsp.Types.Position.create ~line:0 ~character:0 in
       let params =
         Lsp.Types.HoverParams.create ~position ~textDocument:text_document ()
       in
       let _, actions =
         Lsp_server.handle ~dependencies utf16_state
           (request 10 (Lsp.Client_request.TextDocumentHover params))
       in
       has_error Jsonrpc.Response.Error.Code.MethodNotFound actions);
    expect "logs non-diagnostic lint failure"
      (let failing =
         Lsp_server.
           { lint = (fun _ -> Error (Lint_error.Unsupported_file "broken")) }
       in
       match
         Lsp_server.handle ~dependencies:failing utf16_state
           (open_source "let value = 1" 1)
       with
       | _, [ Log _ ] -> true
       | _ -> false);
    expect "rejects unsupported URI"
      (let target = Lsp.Types.DocumentUri.of_string "untitled:example.res" in
       match
         Lsp_server.handle ~dependencies utf16_state (open_at target "text" 1)
       with
       | unchanged, [ Log _ ] -> unchanged == utf16_state
       | _ -> false);
    expect "rejects unsupported file extension"
      (let target =
         Lsp.Types.DocumentUri.of_string "file:///workspace/example.txt"
       in
       match
         Lsp_server.handle ~dependencies utf16_state (open_at target "text" 1)
       with
       | unchanged, [ Log _ ] -> unchanged == utf16_state
       | _ -> false);
    expect "rejects duplicate open"
      (match
         Lsp_server.handle ~dependencies open_state
           (open_source "Console.log(2)" 2)
       with
      | unchanged, [ Log _ ] -> unchanged == open_state
      | _ -> false);
    expect "rejects non-full change"
      (match Lsp_server.handle ~dependencies open_state (empty_change 2) with
      | unchanged, [ Log _ ] -> unchanged == open_state
      | _ -> false);
    expect "rejects change for unopened document"
      (match
         Lsp_server.handle ~dependencies utf16_state (change_source "x" 1)
       with
      | unchanged, [ Log _ ] -> unchanged == utf16_state
      | _ -> false);
    expect "rejects close for unopened document"
      (match Lsp_server.handle ~dependencies utf16_state close_source with
      | unchanged, [ Log _ ] -> unchanged == utf16_state
      | _ -> false);
    expect "accepts initialized and trace notifications"
      (let state, initialized_actions =
         Lsp_server.handle ~dependencies utf16_state
           (notification Lsp.Client_notification.Initialized)
       in
       let trace =
         Lsp.Types.SetTraceParams.create ~value:Lsp.Types.TraceValues.Off
       in
       let next, trace_actions =
         Lsp_server.handle ~dependencies state
           (notification (Lsp.Client_notification.SetTrace trace))
       in
       next == state && initialized_actions = [] && trace_actions = []);
    expect "ignores unknown notification"
      (let raw = Jsonrpc.Notification.create ~method_:"custom/event" () in
       match
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Notification raw)
       with
       | unchanged, [] -> unchanged == utf16_state
       | _ -> false);
    expect "logs unsupported known notification"
      (let text_document = Lsp.Types.TextDocumentIdentifier.create ~uri in
       let saved =
         Lsp.Types.DidSaveTextDocumentParams.create ~textDocument:text_document
           ()
       in
       match
         Lsp_server.handle ~dependencies utf16_state
           (notification (Lsp.Client_notification.DidSaveTextDocument saved))
       with
       | unchanged, [ Log _ ] -> unchanged == utf16_state
       | _ -> false);
    expect "logs malformed notification"
      (let malformed =
         Jsonrpc.Notification.create ~method_:"textDocument/didOpen" ()
       in
       match
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Notification malformed)
       with
       | unchanged, [ Log _ ] -> unchanged == utf16_state
       | _ -> false);
    expect "logs notification before initialize"
      (match
         Lsp_server.handle ~dependencies Lsp_server.initial
           (notification Lsp.Client_notification.Initialized)
       with
      | unchanged, [ Log _ ] -> unchanged == Lsp_server.initial
      | _ -> false);
    expect "ignores notification after shutdown"
      (let shutdown_state, _ =
         Lsp_server.handle ~dependencies utf16_state
           (request 11 Lsp.Client_request.Shutdown)
       in
       match
         Lsp_server.handle ~dependencies shutdown_state
           (notification Lsp.Client_notification.Initialized)
       with
       | unchanged, [] -> unchanged == shutdown_state
       | _ -> false);
    expect "handles request and notification batch"
      (let capabilities = Lsp.Types.ClientCapabilities.create () in
       let params = Lsp.Types.InitializeParams.create ~capabilities () in
       let initialize_request =
         Lsp.Client_request.to_jsonrpc_request
           (Lsp.Client_request.Initialize params) ~id:(`Int 12)
       in
       let initialized_notification =
         Lsp.Client_notification.to_jsonrpc Lsp.Client_notification.Initialized
       in
       match
         Lsp_server.handle ~dependencies Lsp_server.initial
           (Jsonrpc.Packet.Batch_call
              [
                `Request initialize_request;
                `Notification initialized_notification;
              ])
       with
       | state, [ Send _ ] -> Lsp_server.lifecycle state = Running
       | _ -> false);
    expect "logs unexpected responses"
      (let response = Jsonrpc.Response.ok (`Int 13) `Null in
       let _, one =
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Response response)
       in
       let _, batch =
         Lsp_server.handle ~dependencies utf16_state
           (Jsonrpc.Packet.Batch_response [ response ])
       in
       match (one, batch) with [ Log _ ], [ Log _ ] -> true | _ -> false);
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
