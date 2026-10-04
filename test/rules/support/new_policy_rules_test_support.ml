open Rescript_linter

let check ?(kind = Source.Implementation)
    ?(context = Semantic_model.default_context) ?(max_lines = 300)
    ?(max_switch_cases = 10) ?expected_range id count text =
  let source =
    Source.
      {
        filename = (if kind = Interface then "Policy.resi" else "Policy.res");
        text;
        kind;
      }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (fun tree ->
      let findings =
        Syntax_policy_rules.check ~max_lines ~max_switch_cases ~source tree
        @ Idiom_rules.check ~context ~source tree
      in
      let selected =
        List.filter (fun (finding : Diagnostic.t) -> finding.rule = id) findings
      in
      if
        List.length selected = count
        && List.for_all
             (fun (finding : Diagnostic.t) ->
               finding.fixes = []
               && finding.range.start.byte_offset >= 0
               && finding.range.finish.byte_offset <= String.length text
               && Option.fold ~none:true
                    ~some:(fun range -> finding.range = range)
                    expected_range)
             selected
      then Ok ()
      else
        Error
          (Printf.sprintf "%s expected %d, got %d: %s" id count
             (List.length selected) text))

let project_dict_shadow =
  let source =
    Source.
      {
        filename = "Dict.resi";
        kind = Interface;
        text = "type t<'a> = array<'a>";
      }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (function
      | Parser.Interface signature ->
          let context =
            {
              Semantic_model.default_context with
              project_modules = [ "Dict" ];
              module_signatures = [ ("Dict", signature) ];
            }
          in
          check ~context "preferred-type-syntax" 0 "type values = Dict.t<int>"
      | _ -> Error "Expected interface")

let integration =
  let id = "no-optional-some" in
  let text =
    "let consume = (~value=?, ()) => value\n\
     let value = consume(~value=?Some(1), ())"
  in
  let source =
    Source.{ filename = "Integration.res"; kind = Implementation; text }
  in
  Result.bind (Rule_config.set Rule_config.default ~id ~enabled:true)
    (fun config ->
      let findings source =
        Linter.lint_source_with_rules config source
        |> Result.map_error Lint_error.render
      in
      Result.bind (findings source) (function
        | [ finding ] when finding.rule = id ->
            let text =
              "// rescript-lint-disable no-optional-some -- explicit adapter\n"
              ^ text ^ "\n// rescript-lint-enable no-optional-some\n"
            in
            Result.bind
              (findings { source with text })
              (fun findings ->
                if findings = [] then Ok () else Error "Suppression not honored")
        | _ -> Error "Rule not integrated"))
