open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "expressions.res"; text; kind }

let diagnostics ?kind text =
  let source = source ?kind text in
  Parser.parse source
  |> Result.map_error Lint_error.render
  |> Result.map (Expression_rules.check ~source)

let check ?kind expected text =
  Result.bind (diagnostics ?kind text) (fun diagnostics ->
      let actual =
        List.map (fun (item : Diagnostic.t) -> item.rule) diagnostics
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " actual)
             text))

let boolean = check [ "simplify-boolean-expression" ]
let concat = check [ "no-useless-concat" ]
let constant = check [ "approx-constant" ]
