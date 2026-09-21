type lifecycle =
  | Waiting_for_initialize
  | Running
  | Shutdown_requested
  | Stopped

type action = Send of Jsonrpc.Packet.t | Log of string | Exit of int

type dependencies = {
  lint : Source.t -> (Diagnostic.t list, Lint_error.t) result;
}

type t

val initial : t
val lifecycle : t -> lifecycle
val encoding : t -> Lsp_position.encoding
val document : uri:string -> t -> Lsp_document.t option

val handle :
  dependencies:dependencies -> t -> Jsonrpc.Packet.t -> t * action list
