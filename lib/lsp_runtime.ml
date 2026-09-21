type channels = {
  input : in_channel;
  output : out_channel;
  error : out_channel;
}

let log channel message =
  try
    output_string channel (message ^ "\n");
    flush channel;
    Ok ()
  with Sys_error detail -> Error detail

let execute channels action =
  match action with
  | Lsp_server.Send packet ->
      Result.map (fun () -> None) (Lsp_transport.write channels.output packet)
  | Lsp_server.Log message ->
      Result.map_error
        (fun detail -> Lsp_transport.Io_error detail)
        (log channels.error message)
      |> Result.map (fun () -> None)
  | Lsp_server.Exit code -> Ok (Some code)

let rec execute_all channels = function
  | [] -> Ok None
  | action :: rest -> (
      match execute channels action with
      | Error error -> Error error
      | Ok (Some code) -> Ok (Some code)
      | Ok None -> execute_all channels rest)

let report_error channels error =
  ignore
    (log channels.error
       ("rescript-lint lsp: " ^ Lsp_transport.render_error error));
  1

let eof_exit_code state =
  match Lsp_server.lifecycle state with
  | Lsp_server.Shutdown_requested | Lsp_server.Stopped -> 0
  | Lsp_server.Waiting_for_initialize | Lsp_server.Running -> 1

let run ~dependencies channels =
  let input = Lsp_transport.create_input channels.input in
  let rec loop state =
    match Lsp_transport.read input with
    | Error error -> report_error channels error
    | Ok None -> eof_exit_code state
    | Ok (Some packet) -> (
        let next, actions = Lsp_server.handle ~dependencies state packet in
        match execute_all channels actions with
        | Error error -> report_error channels error
        | Ok (Some code) -> code
        | Ok None -> loop next)
  in
  loop Lsp_server.initial
