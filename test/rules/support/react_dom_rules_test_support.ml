open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "react-dom.res"; text; kind }

let check ?kind ?module_signatures name expected text =
  let source = source ?kind text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let diagnostics =
        React_dom_rules.check ?module_signatures ~source tree
        |> List.filter (fun (item : Diagnostic.t) ->
            item.rule = "react/" ^ name)
      in
      if List.length diagnostics = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d for %s" name expected
             (List.length diagnostics) text)

let yes name text = check name 1 ("let view = " ^ text)
let no name text = check name 0 ("let view = " ^ text)

let with_prelude name expected signature text =
  match Parser.parse (source ~kind:Source.Interface signature) with
  | Ok (Parser.Interface items) ->
      check ~module_signatures:[ ("Prelude", items) ] name expected text
  | Ok _ -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)
