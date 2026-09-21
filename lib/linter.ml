let rules = [ No_console.rule; No_object_magic.rule; No_unsafe.rule ]
let any config ids = List.exists (Rule_config.enabled config) ids
let enabled_findings config ids check = if any config ids then check () else []

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

let jsx_findings ~config ~context ~source tree =
  let run = enabled_findings config in
  run Jsx_rules.rule_ids (fun () ->
      Jsx_rules.check
        ~module_signatures:context.Semantic_model.module_signatures ~source tree)
  @ run React_dom_rules.rule_ids (fun () ->
      React_dom_rules.check ~module_signatures:context.module_signatures ~source
        tree)
  @ run React_semantic_rules.rule_ids (fun () ->
      React_semantic_rules.check ~context ~source tree)

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
    let jsx = jsx_findings ~config ~context ~source tree in
    let tests =
      if any config Test_rules.rule_ids then
        Test_rules.check ~module_signatures:context.module_signatures
          ~max_nested_describe:options.max_nested_describe ~source tree
      else []
    in
    Ok (jsx @ tests)

let throws_scope ~config ~project ~source =
  let options = Rule_config.options config in
  let scope =
    Option.map
      (fun Project_options.Rescript_12_3_1 -> Throws_runtime.scope)
      options.throws_runtime
  in
  match (options.throws_dependencies, project) with
  | [], _ -> Ok scope
  | _ :: _, None ->
      adapter_error source
        "throwsDependencies requires a configured project root."
  | roots, Some project ->
      let project_modules =
        List.map
          (fun unit -> unit.Project_files.name)
          project.Project_files.units
      in
      Result.bind (Throws_packages.load ~roots) (fun packages ->
          Throws_packages.scope
            ~initial:(Option.value ~default:Throws_scope.initial scope)
            ~project_modules packages
          |> Result.map Option.some)

let throws_findings ~config ~project ~source tree =
  if not (Rule_config.enabled config "no-unhandled-throws") then Ok []
  else
    Result.bind (throws_scope ~config ~project ~source) (fun scope ->
        match project with
        | None -> No_unhandled_throws.check ?scope ~source tree
        | Some project -> Throws_project.check ?scope ~project ~source tree)

let extended ~load_project ~config ~source document =
  Result.bind (load_project ~config ~source) (fun project ->
      let context = Project_context.semantic ~config ~source project in
      let banned =
        Banned_api.check ~context ~rules ~source document.Parser.tree
      in
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
                      (banned, adapters @ semantic @ project_findings @ throws))
                    (throws_findings ~config ~project ~source document.tree)))))

let optional_syntax_findings ~config ~source document =
  let options = Rule_config.options config in
  enabled_findings config Expression_rules.rule_ids (fun () ->
      Expression_rules.check ~source document.Parser.tree)
  @ enabled_findings config Policy_rules.rule_ids (fun () ->
      Policy_rules.check ~limits:options.limits
        ~warning_policy:options.warning_comments ~source document)

let lint_source_with_loader ~load_project config (source : Source.t) =
  let config = Rule_config.for_file ~filename:source.filename config in
  Result.bind (Parser.parse_document source) (fun document ->
      let tree = document.Parser.tree in
      Result.bind (extended ~load_project ~config ~source document)
        (fun (banned, extended) ->
          Ok
            (List.filter
               (fun (finding : Diagnostic.t) ->
                 Rule_config.enabled config finding.rule)
               (banned
               @ Rules_of_hooks.check ~source tree
               @ Control_flow_rules.check ~source tree
               @ Exception_rules.check ~source tree
               @ optional_syntax_findings ~config ~source document
               @ Blank_lines.check ~source document
               @ extended)
            |> Suppressions.apply
                 ~known_rules:
                   (List.map
                      (fun rule -> rule.Rule_config.id)
                      Rule_config.rules)
                 ~source document
            |> Source_range.sort)))

let lint_source_with_rules config source =
  lint_source_with_loader ~load_project:Project_context.load config source

let lint_source source = lint_source_with_rules Rule_config.default source

let lint_file_with_rules rules filename =
  Result.bind (Source.read filename) (lint_source_with_rules rules)

let lint_file filename = Result.bind (Source.read filename) lint_source
