type t =
  | Read_error of { filename : string; detail : string }
  | Write_error of { filename : string; detail : string }
  | Fix_error of { filename : string; detail : string }
  | Unsupported_file of string
  | Parse_errors of Diagnostic.t * Diagnostic.t list
  | Analysis_errors of Diagnostic.t * Diagnostic.t list

let diagnostics = function
  | Parse_errors (first, rest) | Analysis_errors (first, rest) ->
      Some (first :: rest)
  | Read_error _ | Write_error _ | Fix_error _ | Unsupported_file _ -> None

let render = function
  | Read_error { filename; detail } ->
      Printf.sprintf "%s: Cannot read file: %s" filename detail
  | Write_error { filename; detail } ->
      Printf.sprintf "%s: Cannot write file: %s" filename detail
  | Fix_error { filename; detail } ->
      Printf.sprintf "%s: Cannot apply fixes: %s" filename detail
  | Unsupported_file filename ->
      Printf.sprintf "%s: Expected a .res or .resi file." filename
  | Parse_errors (first, rest) | Analysis_errors (first, rest) ->
      String.concat "\n" (List.map Diagnostic.render (first :: rest))
