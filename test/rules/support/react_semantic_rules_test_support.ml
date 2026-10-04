open Rescript_linter

let check rule expected text =
  let source = Source.{ filename = "react.res"; kind = Implementation; text } in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let findings =
        React_semantic_rules.check ~source tree
        |> List.filter (fun (finding : Diagnostic.t) -> finding.rule = rule)
      in
      if List.length findings = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s expected %d got %d: %s" rule expected
             (List.length findings) text)

let nested = check "react/no-unstable-nested-components"
let props = check "react/no-new-prop-value"
let context = check "react/jsx-no-constructed-context-values"
let deps = check "react/exhaustive-deps"
