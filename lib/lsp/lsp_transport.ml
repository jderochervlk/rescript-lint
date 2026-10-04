type limits = { max_header_bytes : int; max_message_bytes : int }

type error =
  | Header_too_large of { limit : int }
  | Message_too_large of { length : int; limit : int }
  | Unexpected_eof
  | Io_error of string
  | Protocol_error of string

type input = {
  channel : in_channel;
  limits : limits;
  mutable header_bytes : int;
}

exception Boundary_error of error

let default_limits =
  { max_header_bytes = 64 * 1024; max_message_bytes = 16 * 1024 * 1024 }

module Identity = struct
  type 'a t = 'a

  let return value = value
  let raise exception_ = Stdlib.raise exception_

  module O = struct
    let ( let+ ) value transform = transform value
    let ( let* ) value transform = transform value
  end
end

module Channel = struct
  type nonrec input = input
  type output = out_channel

  let add_header_byte input =
    input.header_bytes <- input.header_bytes + 1;
    if input.header_bytes > input.limits.max_header_bytes then
      raise
        (Boundary_error
           (Header_too_large { limit = input.limits.max_header_bytes }))

  let read_line input =
    let buffer = Buffer.create 80 in
    let rec read () =
      match input_char input.channel with
      | '\n' ->
          add_header_byte input;
          let line = Buffer.contents buffer in
          if line = "" || line = "\r" then input.header_bytes <- 0;
          Some line
      | character ->
          add_header_byte input;
          Buffer.add_char buffer character;
          read ()
      | exception End_of_file ->
          if Buffer.length buffer = 0 then None
          else raise (Boundary_error Unexpected_eof)
      | exception Sys_error detail -> raise (Boundary_error (Io_error detail))
    in
    read ()

  let read_exactly input length =
    if length < 0 || length > input.limits.max_message_bytes then
      raise
        (Boundary_error
           (Message_too_large { length; limit = input.limits.max_message_bytes }))
    else
      try Some (really_input_string input.channel length) with
      | End_of_file -> None
      | Sys_error detail -> raise (Boundary_error (Io_error detail))

  let write output chunks =
    try
      List.iter (output_string output) chunks;
      flush output
    with Sys_error detail -> raise (Boundary_error (Io_error detail))
end

module Protocol = Lsp.Io.Make (Identity) (Channel)

let create_input ?(limits = default_limits) channel =
  { channel; limits; header_bytes = 0 }

let protect operation =
  try Ok (operation ()) with
  | Boundary_error error -> Error error
  | Lsp.Io.Error detail -> Error (Protocol_error detail)
  | Jsonrpc.Json.Of_json (detail, _) -> Error (Protocol_error detail)
  | Yojson.Json_error detail -> Error (Protocol_error detail)
  | Sys_error detail -> Error (Io_error detail)
  | exception_ -> Error (Protocol_error (Printexc.to_string exception_))

let read input = protect (fun () -> Protocol.read input)
let write output packet = protect (fun () -> Protocol.write output packet)

let render_error = function
  | Header_too_large { limit } ->
      Printf.sprintf "LSP header exceeds the %d-byte limit." limit
  | Message_too_large { length; limit } ->
      Printf.sprintf "LSP message length %d exceeds the %d-byte limit." length
        limit
  | Unexpected_eof -> "Unexpected end of input while reading an LSP header."
  | Io_error detail -> "LSP input/output error: " ^ detail
  | Protocol_error detail -> "Invalid LSP message: " ^ detail
