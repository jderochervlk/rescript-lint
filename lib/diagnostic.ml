type position = { line : int; column : int; byte_offset : int }
type range = { start : position; finish : position }
type t = { rule : string; message : string; filename : string; range : range }

let render diagnostic =
  Printf.sprintf "%s:%d:%d: error [%s] %s" diagnostic.filename
    diagnostic.range.start.line diagnostic.range.start.column diagnostic.rule
    diagnostic.message
