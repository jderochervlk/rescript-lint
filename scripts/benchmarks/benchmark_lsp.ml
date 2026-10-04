open Rescript_linter

type client = {
  input : in_channel;
  output : out_channel;
  transport : Lsp_transport.input;
}

let request id typed =
  Jsonrpc.Packet.Request
    (Lsp.Client_request.to_jsonrpc_request typed ~id:(`Int id))

let notification typed =
  Jsonrpc.Packet.Notification (Lsp.Client_notification.to_jsonrpc typed)

let initialize =
  let capabilities = Lsp.Types.ClientCapabilities.create () in
  request 1
    (Lsp.Client_request.Initialize
       (Lsp.Types.InitializeParams.create ~capabilities ()))

let uri = Lsp.Types.DocumentUri.of_string "file:///benchmark/Example.res"

let opened text =
  let textDocument =
    Lsp.Types.TextDocumentItem.create ~languageId:"rescript" ~text ~uri
      ~version:1
  in
  notification
    (Lsp.Client_notification.TextDocumentDidOpen
       (Lsp.Types.DidOpenTextDocumentParams.create ~textDocument))

let changed text version =
  let textDocument =
    Lsp.Types.VersionedTextDocumentIdentifier.create ~uri ~version
  in
  let change = Lsp.Types.TextDocumentContentChangeEvent.create ~text () in
  notification
    (Lsp.Client_notification.TextDocumentDidChange
       (Lsp.Types.DidChangeTextDocumentParams.create ~textDocument
          ~contentChanges:[ change ]))

let send client packet =
  Result.map_error Lsp_transport.render_error
    (Lsp_transport.write client.output packet)

let receive client =
  let ready, _, _ =
    Unix.select [ Unix.descr_of_in_channel client.input ] [] [] 30.
  in
  if ready = [] then Error "Timed out waiting for the language server."
  else
    Result.bind
      (Result.map_error Lsp_transport.render_error
         (Lsp_transport.read client.transport))
      (function
        | Some packet -> Ok packet | None -> Error "Unexpected server EOF.")

let exchange client packet =
  Result.bind (send client packet) (fun () -> receive client)

let response id = function
  | Jsonrpc.Packet.Response { id = `Int actual; result = Ok _ } when actual = id
    ->
      Ok ()
  | _ -> Error "Expected a successful lifecycle response."

let diagnostics version = function
  | Jsonrpc.Packet.Notification raw -> (
      match Lsp.Server_notification.of_jsonrpc raw with
      | Ok (Lsp.Server_notification.PublishDiagnostics params)
        when params.uri = uri && params.version = Some version ->
          Ok (List.length params.diagnostics)
      | _ -> Error "Expected diagnostics for the current document version.")
  | _ -> Error "Expected a diagnostics notification."

let timed run =
  let start = Unix.gettimeofday () in
  Result.map
    (fun value -> ((Unix.gettimeofday () -. start) *. 1000., value))
    (run ())

let rec samples client text version remaining values =
  if remaining = 0 then Ok (List.rev values)
  else
    let run () =
      Result.bind (exchange client (changed text version)) (diagnostics version)
    in
    Result.bind (timed run) (fun (elapsed, _) ->
        samples client text (version + 1) (remaining - 1) (elapsed :: values))

let percentile fraction values =
  let sorted = List.sort Float.compare values in
  let index =
    max 0
      (int_of_float (ceil (fraction *. float_of_int (List.length sorted))) - 1)
  in
  Option.value ~default:0. (List.nth_opt sorted index)

let measure client text start =
  Result.bind (exchange client initialize) (fun packet ->
      Result.bind (response 1 packet) (fun () ->
          let startup = (Unix.gettimeofday () -. start) *. 1000. in
          Result.bind
            (timed (fun () -> exchange client (opened text)))
            (fun (opening, packet) ->
              Result.bind (diagnostics 1 packet) (fun findings ->
                  Result.map
                    (fun values -> (startup, opening, findings, values))
                    (samples client text 2 20 [])))))

let finish client =
  Result.bind
    (exchange client (request 2 Lsp.Client_request.Shutdown))
    (fun packet ->
      Result.bind (response 2 packet) (fun () ->
          send client (notification Lsp.Client_notification.Exit)))

let with_server binary arguments text =
  try
    let start = Unix.gettimeofday () in
    let channels =
      Unix.open_process_args_full binary
        (Array.of_list (binary :: "lsp" :: "--stdio" :: arguments))
        (Unix.environment ())
    in
    let input, output, errors = channels in
    let client =
      { input; output; transport = Lsp_transport.create_input input }
    in
    let result = measure client text start in
    let result =
      Result.bind result (fun values ->
          Result.map (fun () -> values) (finish client))
    in
    close_out_noerr output;
    let error_text = In_channel.input_all errors in
    match Unix.close_process_full channels with
    | Unix.WEXITED 0 when error_text = "" -> result
    | _ -> Error ("Server failed: " ^ error_text)
  with
  | Sys_error detail -> Error detail
  | Unix.Unix_error (error, operation, _) ->
      Error (operation ^ ": " ^ Unix.error_message error)

let cases =
  [
    ("clean", [], fun index -> Printf.sprintf "let value%d = %d" index index);
    ( "invalid",
      [],
      fun index ->
        if index = 0 then "let ="
        else Printf.sprintf "let value%d = %d" index index );
    ( "jsx",
      [ "--jsx-runtime"; "react-dom"; "--enable-rule"; "jsx-a11y/alt-text" ],
      fun index -> Printf.sprintf "let view%d = <img alt=\"benchmark\" />" index
    );
    ( "hooks",
      [],
      fun index ->
        Printf.sprintf "let useBench%d = () => React.useState(() => %d)" index
          index );
    ( "throws",
      [],
      fun index ->
        if index mod 2 = 0 then
          Printf.sprintf "@throws let run%d = () => %d" index index
        else "" );
  ]

let run_case binary lines (name, arguments, line) =
  let text = String.concat "\n" (List.init lines line) ^ "\n" in
  Result.map
    (fun (startup, opening, findings, values) ->
      Printf.printf "%s,%d,%d,%.3f,%.3f,%.3f,%.3f,%d\n%!" name lines
        (String.length text) startup opening (percentile 0.5 values)
        (percentile 0.95 values) findings)
    (with_server binary arguments text)

let run binary =
  print_endline
    "fixture,lines,bytes,startup_ms,open_ms,change_median_ms,change_p95_ms,diagnostics";
  List.fold_left
    (fun result lines ->
      List.fold_left
        (fun result case ->
          Result.bind result (fun () -> run_case binary lines case))
        result cases)
    (Ok ()) [ 500; 2000; 5000 ]

let () =
  let result =
    match Array.to_list Sys.argv with
    | [ _; binary ] -> run binary
    | _ -> Error "Usage: benchmark_lsp PATH_TO_RELEASE_BINARY"
  in
  match result with
  | Ok () -> ()
  | Error detail ->
      prerr_endline detail;
      exit 1
