let rules = [ No_console.rule; No_object_magic.rule; No_unsafe.rule ]
let any config ids = List.exists (Rule_config.enabled config) ids

let adapter_error source message =
  let point = Diagnostic.{ line = 1; column = 1; byte_offset = 0 } in
  Error
    (Lint_error.Analysis_errors
       ( Diagnostic.
           {
             filename = source.Source.filename;
             rule = "adapter-analysis";
             message;
             fixes = [];
             range = { start = point; finish = point };
           },
         [] ))

let adapter_findings ~config ~context ~source tree =
  let options = Rule_config.options config in
  let jsx_ids =
    Jsx_rules.rule_ids @ React_dom_rules.rule_ids
    @ React_semantic_rules.rule_ids
  in
  if any config jsx_ids && options.jsx_runtime = None then
    adapter_error source
      "Selected JSX/React rules require --jsx-runtime react-dom."
  else if any config Test_rules.rule_ids && options.test_framework = None then
    adapter_error source
      "Selected test rules require --test-framework rescript-vitest-3."
  else
    let jsx =
      if any config jsx_ids then
        Jsx_rules.check
          ~module_signatures:context.Semantic_model.module_signatures ~source
          tree
        @ React_dom_rules.check ~module_signatures:context.module_signatures
            ~source tree
        @ React_semantic_rules.check ~context ~source tree
      else []
    in
    let tests =
      if any config Test_rules.rule_ids then
        Test_rules.check ~module_signatures:context.module_signatures
          ~max_nested_describe:options.max_nested_describe ~source tree
      else []
    in
    Ok (jsx @ tests)

let extended ~config ~source document =
  Result.bind (Project_context.load ~config ~source) (fun project ->
      let context = Project_context.semantic ~config ~source project in
      Result.bind
        (adapter_findings ~config ~context ~source document.Parser.tree)
        (fun adapters ->
          Result.bind
            (if any config Semantic_rules.rule_ids then
               Semantic_rules.check ~context ~source document.tree
             else Ok [])
            (fun semantic ->
              Result.bind
                (Project_rules.check ~config ~context ~project ~source document)
                (fun project_findings ->
                  Result.map
                    (fun throws ->
                      adapters @ semantic @ project_findings @ throws)
                    (if not (Rule_config.enabled config "no-unhandled-throws")
                     then Ok []
                     else
                       match project with
                       | None -> No_unhandled_throws.check ~source document.tree
                       | Some project ->
                           Throws_project.check ~project ~source document.tree)))))

let lint_source_with_rules config (source : Source.t) =
  Result.bind (Parser.parse_document source) (fun document ->
      let tree = document.Parser.tree in
      Result.bind (extended ~config ~source document) (fun extended ->
          Ok
            (List.filter
               (fun (finding : Diagnostic.t) ->
                 Rule_config.enabled config finding.rule)
               (Banned_api.check ~rules ~source tree
               @ Rules_of_hooks.check ~source tree
               @ Control_flow_rules.check ~source tree
               @ Exception_rules.check ~source tree
               @ Expression_rules.check ~source tree
               @ Policy_rules.check ~limits:(Rule_config.options config).limits
                   ~source document
               @ Blank_lines.check ~source document
               @ extended)
            |> Suppressions.apply
                 ~known_rules:
                   (List.map
                      (fun rule -> rule.Rule_config.id)
                      Rule_config.rules)
                 ~source document
            |> Source_range.sort)))

let lint_source source = lint_source_with_rules Rule_config.default source

let lint_file_with_rules rules filename =
  Result.bind (Source.read filename) (lint_source_with_rules rules)

let lint_file filename = Result.bind (Source.read filename) lint_source
