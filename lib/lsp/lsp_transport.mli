type limits = { max_header_bytes : int; max_message_bytes : int }

type error =
  | Header_too_large of { limit : int }
  | Message_too_large of { length : int; limit : int }
  | Unexpected_eof
  | Io_error of string
  | Protocol_error of string

type input

val default_limits : limits
val create_input : ?limits:limits -> in_channel -> input
val read : input -> (Jsonrpc.Packet.t option, error) result
val write : out_channel -> Jsonrpc.Packet.t -> (unit, error) result
val render_error : error -> string
