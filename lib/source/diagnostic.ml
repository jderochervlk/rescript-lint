type position = { line : int; column : int; byte_offset : int }
type range = { start : position; finish : position }
type symbol_kind = Value | Module | Type
type symbol = { kind : symbol_kind; path : string }
type help = { message : string; url : string option }

type t = {
  rule : string;
  message : string;
  filename : string;
  range : range;
  fixes : Text_edit.t list;
  help : help option;
  symbol : symbol option;
}

let kind_name = function
  | Value -> "value"
  | Module -> "module"
  | Type -> "type"

let detail diagnostic =
  let symbol =
    Option.fold ~none:""
      ~some:(fun symbol ->
        "\n  Resolved " ^ kind_name symbol.kind ^ ": " ^ symbol.path)
      diagnostic.symbol
  in
  let help =
    Option.fold ~none:""
      ~some:(fun (help : help) ->
        "\n  Help: " ^ help.message
        ^ Option.fold ~none:"" ~some:(fun url -> " (" ^ url ^ ")") help.url)
      diagnostic.help
  in
  diagnostic.message ^ symbol ^ help

let render diagnostic =
  Printf.sprintf "%s:%d:%d: error [%s] %s" diagnostic.filename
    diagnostic.range.start.line diagnostic.range.start.column diagnostic.rule
    (detail diagnostic)
