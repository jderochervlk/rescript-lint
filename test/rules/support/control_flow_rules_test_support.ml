open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "control.res"; text; kind }

let check ?kind expected text =
  let source = source ?kind text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let actual =
        Control_flow_rules.check ~source tree
        |> List.map (fun (diagnostic : Diagnostic.t) -> diagnostic.rule)
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " actual)
             text)

let constant_condition text = check [ "no-constant-condition" ] text
let constant_binary text = check [ "no-constant-binary-expression" ] text
let duplicate text = check [ "no-duplicate-condition" ] text
let identical text = check [ "no-identical-branches" ] text

let binary_truth expected text =
  let source = source text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree -> (
      match Control_flow_rules.check ~source tree with
      | [ diagnostic ]
        when diagnostic.rule = "no-constant-binary-expression"
             && diagnostic.message
                = "This binary expression always evaluates to "
                  ^ string_of_bool expected ^ "." ->
          Ok ()
      | diagnostics ->
          Error
            ("Unexpected truth findings: "
            ^ String.concat "; "
                (List.map
                   (fun (diagnostic : Diagnostic.t) -> diagnostic.message)
                   diagnostics)))

let exact_range =
  match
    let source = source "// comment\nlet value = if true {1} else {2}\n" in
    Result.bind (Parser.parse source) (fun tree ->
        Ok (Control_flow_rules.check ~source tree))
  with
  | Ok [ diagnostic ] ->
      diagnostic.rule = "no-constant-condition"
      && diagnostic.range.start.line = 2
      && diagnostic.range.start.column = 16
      && diagnostic.range.finish.column = 20
  | _ -> false

let integrated =
  match Linter.lint_source (source "let value = if true {1} else {2}") with
  | Ok diagnostics ->
      List.exists
        (fun (diagnostic : Diagnostic.t) ->
          diagnostic.rule = "no-constant-condition")
        diagnostics
  | Error _ -> false
