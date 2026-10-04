open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "policy.res"; text; kind }

let diagnostics ?kind ?limits text =
  let source = source ?kind text in
  Result.map (Policy_rules.check ?limits ~source) (Parser.parse_document source)

let check ?kind ?limits expected text =
  match diagnostics ?kind ?limits text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let actual =
        List.map (fun (item : Diagnostic.t) -> item.rule) diagnostics
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " actual)
             text)

let empty text = check [ "no-empty-function" ] text
let warning text = check [ "no-warning-comments" ] text
let nesting = { Policy_rules.default_limits with max_nesting = 1 }
let params = { Policy_rules.default_limits with max_params = 2 }
let lines = { Policy_rules.default_limits with max_lines_per_function = 2 }

let check_range rule start_line start_column finish_line finish_column text =
  match diagnostics text with
  | Ok [ item ]
    when item.rule = rule
         && item.range.start.line = start_line
         && item.range.start.column = start_column
         && item.range.finish.line = finish_line
         && item.range.finish.column = finish_column ->
      Ok ()
  | Ok _ -> Error "Unexpected diagnostic range"
  | Error error -> Error (Lint_error.render error)
