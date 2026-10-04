open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "exceptions.res"; text; kind }

let diagnostics ?kind text =
  let source = source ?kind text in
  Result.map (Exception_rules.check ~source) (Parser.parse source)

let check ?kind expected text =
  match diagnostics ?kind text with
  | Error error -> Error (Lint_error.render error)
  | Ok actual ->
      let rules = List.map (fun (value : Diagnostic.t) -> value.rule) actual in
      if rules = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " rules) text)

let useless = check [ "no-useless-catch" ]
let catch_all = check [ "no-catch-all-exception" ]
let debugger = check [ "no-debugger" ]

let exact_range rule text first last =
  match diagnostics text with
  | Ok [ diagnostic ]
    when diagnostic.rule = rule
         && diagnostic.range.start.byte_offset = first
         && diagnostic.range.finish.byte_offset = last
         && diagnostic.filename = "exceptions.res"
         && diagnostic.fixes = [] ->
      Ok ()
  | _ -> Error "diagnostic range or metadata mismatch"
