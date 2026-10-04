open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "testing.res"; text; kind }

let lint ?kind ?max_nested_describe ?module_signatures text =
  let source = source ?kind text in
  Result.map
    (Test_rules.check ?max_nested_describe ?module_signatures ~source)
    (Parser.parse source)

let check ?kind ?max_nested_describe ?module_signatures rule expected text =
  match lint ?kind ?max_nested_describe ?module_signatures text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let found =
        List.filter
          (fun (value : Diagnostic.t) -> value.rule = rule)
          diagnostics
      in
      if List.length found = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d in %s" rule expected
             (List.length found) text)

let focused = check "test/no-focused-tests"
let disabled = check "test/no-disabled-tests"
let duplicate_title = check "test/no-identical-title"
let duplicate_hook = check "test/no-duplicate-hooks"
let conditional_test = check "test/no-conditional-test"
let conditional_expect = check "test/no-conditional-expect"
let hook_order = check "test/prefer-hooks-in-order"
let hooks_top = check "test/prefer-hooks-on-top"
let top_level = check "test/require-top-level-describe"
let title = check "test/valid-title"
let assertions = check "test/expect-expect"
let depth = check ~max_nested_describe:2 "test/max-nested-describe"

let exact_range =
  match lint "Vitest.test(\"works\", ~only=true, _ => ())" with
  | Ok diagnostics -> (
      match
        List.find_opt
          (fun (value : Diagnostic.t) -> value.rule = "test/no-focused-tests")
          diagnostics
      with
      | Some diagnostic
        when diagnostic.range.start.byte_offset = 27
             && diagnostic.range.finish.byte_offset = 31
             && diagnostic.filename = "testing.res"
             && diagnostic.fixes = [] ->
          Ok ()
      | _ -> Error "focused modifier range mismatch")
  | Error error -> Error (Lint_error.render error)

let project_open ?(name = "Prelude") signature expected text =
  match Parser.parse (source ~kind:Source.Interface signature) with
  | Ok (Parser.Interface signature) ->
      check
        ~module_signatures:[ (name, signature) ]
        "test/no-focused-tests" expected text
  | Ok (Implementation _) -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)
