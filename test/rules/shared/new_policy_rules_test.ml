open Rescript_linter
open New_policy_rules_test_support

let checks =
  List.map
    (fun text ->
      (text, check "no-identity-operation" 1 ("let f = (x: int) => " ^ text)))
    [ "0 + x"; "x - 0"; "x * 1"; "1 * x"; "x / 1" ]

let range_check =
  let text = "// \240\159\152\128\nlet value: Dict.t<int> = dict{}" in
  let source =
    Source.{ filename = "Unicode.res"; kind = Implementation; text }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (fun tree ->
      match
        Idiom_rules.check ~context:Semantic_model.default_context ~source tree
      with
      | [ finding ] when finding.range.start.line = 2 ->
          let start = finding.range.start.byte_offset in
          let length = finding.range.finish.byte_offset - start in
          if String.sub text start length = "Dict.t" then Ok ()
          else Error "Wrong type range"
      | _ -> Error "Missing Unicode type finding")

let extra_checks = [ ("Unicode diagnostic range", range_check) ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ extra_checks)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
