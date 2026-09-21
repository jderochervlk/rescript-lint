type lifecycle =
  | Waiting_for_initialize
  | Running
  | Shutdown_requested
  | Stopped

type action = Send of Jsonrpc.Packet.t | Log of string | Exit of int

type dependencies = {
  lint : Source.t -> (Diagnostic.t list, Lint_error.t) result;
}

type t = {
  lifecycle : lifecycle;
  encoding : Lsp_position.encoding;
  documents : Lsp_document_store.t;
}

let initial =
  {
    lifecycle = Waiting_for_initialize;
    encoding = Lsp_position.Utf16;
    documents = Lsp_document_store.empty;
  }

let lifecycle state = state.lifecycle
let encoding state = state.encoding
let document ~uri state = Lsp_document_store.find ~uri state.documents
let send_response response = [ Send (Jsonrpc.Packet.Response response) ]

let error_response request code message =
  Jsonrpc.Response.Error.make ~code ~message ()
  |> Jsonrpc.Response.error request.Jsonrpc.Request.id
  |> send_response

let success_response (type result) request
    (typed_request : result Lsp.Client_request.t) (result : result) =
  Lsp.Client_request.yojson_of_result typed_request result
  |> Jsonrpc.Response.ok request.Jsonrpc.Request.id
  |> send_response

let negotiate_encoding capabilities =
  let open Lsp.Types in
  match capabilities.ClientCapabilities.general with
  | Some { positionEncodings = Some encodings; _ }
    when List.mem PositionEncodingKind.UTF8 encodings ->
      Lsp_position.Utf8
  | None | Some _ -> Lsp_position.Utf16

let protocol_encoding = function
  | Lsp_position.Utf8 -> Lsp.Types.PositionEncodingKind.UTF8
  | Lsp_position.Utf16 -> Lsp.Types.PositionEncodingKind.UTF16

let server_version = Command.version

let initialize_result encoding =
  let open Lsp.Types in
  let synchronization =
    TextDocumentSyncOptions.create ~openClose:true
      ~change:TextDocumentSyncKind.Full ~save:(`Bool false) ()
  in
  let capabilities =
    ServerCapabilities.create
      ~positionEncoding:(protocol_encoding encoding)
      ~textDocumentSync:(`TextDocumentSyncOptions synchronization) ()
  in
  let server_info =
    InitializeResult.create_serverInfo ~name:"rescript-lint"
      ~version:server_version ()
  in
  InitializeResult.create ~capabilities ~serverInfo:server_info ()

let handle_initialize state request params typed_request =
  match state.lifecycle with
  | Waiting_for_initialize ->
      let encoding =
        negotiate_encoding params.Lsp.Types.InitializeParams.capabilities
      in
      ( { state with lifecycle = Running; encoding },
        success_response request typed_request (initialize_result encoding) )
  | Running | Shutdown_requested | Stopped ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.InvalidRequest
          "Server has already been initialized." )

let handle_shutdown state request typed_request =
  match state.lifecycle with
  | Running ->
      ( { state with lifecycle = Shutdown_requested },
        success_response request typed_request () )
  | Waiting_for_initialize ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.ServerNotInitialized
          "Server is not initialized." )
  | Shutdown_requested | Stopped ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.InvalidRequest
          "Shutdown has already been requested." )

let unsupported_request state request =
  match state.lifecycle with
  | Waiting_for_initialize ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.ServerNotInitialized
          "Server is not initialized." )
  | Running ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.MethodNotFound
          ("Unsupported request: " ^ request.method_) )
  | Shutdown_requested | Stopped ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.InvalidRequest
          "Server is shutting down." )

let handle_request state request =
  match Lsp.Client_request.of_jsonrpc request with
  | Error detail ->
      ( state,
        error_response request Jsonrpc.Response.Error.Code.InvalidParams detail
      )
  | Ok (Lsp.Client_request.E typed_request) -> (
      match typed_request with
      | Lsp.Client_request.Initialize params ->
          handle_initialize state request params typed_request
      | Lsp.Client_request.Shutdown ->
          handle_shutdown state request typed_request
      | Lsp.Client_request.UnknownRequest _ -> unsupported_request state request
      | _ -> unsupported_request state request)

let publish uri version diagnostics =
  let params =
    Lsp.Types.PublishDiagnosticsParams.create ~uri ~version ~diagnostics ()
  in
  Lsp.Server_notification.PublishDiagnostics params
  |> Lsp.Server_notification.to_jsonrpc
  |> fun notification -> Send (Jsonrpc.Packet.Notification notification)

let lint_effect dependencies state uri document =
  let result = dependencies.lint (Lsp_document.source document) in
  match
    Lsp_diagnostics.of_lint_result ~document ~encoding:state.encoding result
  with
  | Ok diagnostics ->
      [ publish uri (Lsp_document.version document) diagnostics ]
  | Error error -> [ Log (Lsp_diagnostics.render_error error) ]

let open_document dependencies state params =
  let item = params.Lsp.Types.DidOpenTextDocumentParams.textDocument in
  let uri = item.uri in
  let rendered_uri = Lsp.Types.DocumentUri.to_string uri in
  match Lsp_uri.local_path uri with
  | Error error -> (state, [ Log (Lsp_uri.render_error error) ])
  | Ok path -> (
      match
        Lsp_document.create
          {
            uri = rendered_uri;
            path;
            language_id = item.languageId;
            version = item.version;
            text = item.text;
          }
      with
      | Error error -> (state, [ Log (Lint_error.render error) ])
      | Ok document -> (
          match Lsp_document_store.open_document document state.documents with
          | Error error ->
              (state, [ Log (Lsp_document_store.render_error error) ])
          | Ok documents ->
              let next = { state with documents } in
              (next, lint_effect dependencies next uri document)))

let full_change changes =
  match changes with
  | [ { Lsp.Types.TextDocumentContentChangeEvent.range = None; text; _ } ] ->
      Some text
  | [] | _ :: _ -> None

let change_document dependencies state params =
  let identifier = params.Lsp.Types.DidChangeTextDocumentParams.textDocument in
  let uri = identifier.uri in
  let rendered_uri = Lsp.Types.DocumentUri.to_string uri in
  match full_change params.contentChanges with
  | None ->
      (state, [ Log ("Expected one full-document change for " ^ rendered_uri) ])
  | Some text -> (
      match
        Lsp_document_store.change ~uri:rendered_uri ~version:identifier.version
          ~text state.documents
      with
      | Error error -> (state, [ Log (Lsp_document_store.render_error error) ])
      | Ok (document, documents) ->
          let next = { state with documents } in
          (next, lint_effect dependencies next uri document))

let close_document state params =
  let uri = params.Lsp.Types.DidCloseTextDocumentParams.textDocument.uri in
  let rendered_uri = Lsp.Types.DocumentUri.to_string uri in
  match Lsp_document_store.close ~uri:rendered_uri state.documents with
  | Error error -> (state, [ Log (Lsp_document_store.render_error error) ])
  | Ok (document, documents) ->
      ( { state with documents },
        [ publish uri (Lsp_document.version document) [] ] )

let handle_running_notification dependencies state = function
  | Lsp.Client_notification.TextDocumentDidOpen params ->
      open_document dependencies state params
  | Lsp.Client_notification.TextDocumentDidChange params ->
      change_document dependencies state params
  | Lsp.Client_notification.TextDocumentDidClose params ->
      close_document state params
  | Lsp.Client_notification.Initialized | Lsp.Client_notification.SetTrace _ ->
      (state, [])
  | Lsp.Client_notification.UnknownNotification _ -> (state, [])
  | notification ->
      let raw = Lsp.Client_notification.to_jsonrpc notification in
      (state, [ Log ("Ignored notification: " ^ raw.method_) ])

let handle_notification dependencies state notification =
  match Lsp.Client_notification.of_jsonrpc notification with
  | Error detail -> (state, [ Log ("Invalid notification: " ^ detail) ])
  | Ok Lsp.Client_notification.Exit ->
      let code = if state.lifecycle = Shutdown_requested then 0 else 1 in
      ({ state with lifecycle = Stopped }, [ Exit code ])
  | Ok notification -> (
      match state.lifecycle with
      | Running -> handle_running_notification dependencies state notification
      | Waiting_for_initialize ->
          (state, [ Log "Ignored notification before initialization." ])
      | Shutdown_requested | Stopped -> (state, []))

let handle_call dependencies state = function
  | `Request request -> handle_request state request
  | `Notification notification ->
      handle_notification dependencies state notification

let handle_batch dependencies state calls =
  List.fold_left
    (fun (current, effects) call ->
      let next, produced = handle_call dependencies current call in
      (next, List.rev_append produced effects))
    (state, []) calls
  |> fun (next, reversed) -> (next, List.rev reversed)

let handle ~dependencies state = function
  | Jsonrpc.Packet.Request request -> handle_request state request
  | Jsonrpc.Packet.Notification notification ->
      handle_notification dependencies state notification
  | Jsonrpc.Packet.Batch_call calls -> handle_batch dependencies state calls
  | Jsonrpc.Packet.Response _ | Jsonrpc.Packet.Batch_response _ ->
      (state, [ Log "Ignored unexpected client response." ])
