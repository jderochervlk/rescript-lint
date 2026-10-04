let ( let* ) = Result.bind
let banned_api_rules = [ No_console.rule; No_object_magic.rule; No_unsafe.rule ]
let any_enabled config ids = List.exists (Rule_config.enabled config) ids

let check_if_enabled config ids check =
  if any_enabled config ids then check () else []

let adapter_error source message =
  let point = Diagnostic.{ line = 1; column = 1; byte_offset = 0 } in
  Error
    (Lint_error.Analysis_errors
       ( Diagnostic.
           {
             filename = source.Source.filename;
             rule = "adapter-analysis";
             message;
             help = None;
             symbol = None;
             fixes = [];
             range = { start = point; finish = point };
           },
         [] ))

let check_react_rules ~config ~context ~source tree =
  let check = check_if_enabled config in
  check Jsx_rules.rule_ids (fun () ->
      Jsx_rules.check
        ~module_signatures:context.Semantic_model.module_signatures ~source tree)
  @ check React_dom_rules.rule_ids (fun () ->
      React_dom_rules.check ~module_signatures:context.module_signatures ~source
        tree)
  @ check React_semantic_rules.rule_ids (fun () ->
      React_semantic_rules.check ~context ~source tree)

let check_framework_rules ~config ~context ~source tree =
  let options = Rule_config.options config in
  let react_ids =
    Jsx_rules.rule_ids @ React_dom_rules.rule_ids
    @ React_semantic_rules.rule_ids
  in
  if any_enabled config react_ids && options.jsx_runtime = None then
    adapter_error source
      "Selected JSX/React rules require --jsx-runtime react-dom."
  else if
    any_enabled config Test_rules.rule_ids && options.test_framework = None
  then
    adapter_error source
      "Selected test rules require --test-framework rescript-vitest-3."
  else
    let react = check_react_rules ~config ~context ~source tree in
    let tests =
      check_if_enabled config Test_rules.rule_ids (fun () ->
          Test_rules.check ~module_signatures:context.module_signatures
            ~max_nested_describe:options.max_nested_describe ~source tree)
    in
    Ok (react @ tests)

let load_throws_scope ~config ~project ~source =
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
      let* packages =
        Dependency_packages.load ~context:Throws_dependencies ~roots
      in
      Throws_packages.scope
        ~initial:(Option.value ~default:Throws_scope.initial scope)
        ~project_modules packages
      |> Result.map Option.some

let check_throws ~config ~project ~source tree =
  if not (Rule_config.enabled config "no-unhandled-throws") then Ok []
  else
    let* scope = load_throws_scope ~config ~project ~source in
    match project with
    | None -> No_unhandled_throws.check ?scope ~source tree
    | Some project -> Throws_project.check ?scope ~project ~source tree

let check_idiom_rules ~config ~context ~source tree =
  check_if_enabled config Idiom_rules.rule_ids (fun () ->
      Idiom_rules.check ~context ~source tree)

let check_optional_syntax_rules ~config ~source document =
  let options = Rule_config.options config in
  let check = check_if_enabled config in
  check Expression_rules.rule_ids (fun () ->
      Expression_rules.check ~source document.Parser.tree)
  @ check Policy_rules.rule_ids (fun () ->
      Policy_rules.check ~limits:options.limits
        ~warning_policy:options.warning_comments ~source document)
  @ check Syntax_policy_rules.rule_ids (fun () ->
      Syntax_policy_rules.check ~max_lines:options.max_lines
        ~max_switch_cases:options.max_switch_cases ~source document.tree)

let check_syntax_rules ~config ~source document =
  let tree = document.Parser.tree in
  React_rules_of_hooks.check ~source tree
  @ Control_flow_rules.check ~source tree
  @ Exception_rules.check ~source tree
  @ check_optional_syntax_rules ~config ~source document
  @ Blank_lines.check ~source document

let check_semantic_rules ~config ~context ~source tree =
  if any_enabled config Semantic_rules.rule_ids then
    Semantic_rules.check ~context ~source tree
  else Ok []

let check ~config ~context ~project ~source document =
  let tree = document.Parser.tree in
  let banned = Banned_api.check ~context ~rules:banned_api_rules ~source tree in
  let idioms = check_idiom_rules ~config ~context ~source tree in
  let* frameworks = check_framework_rules ~config ~context ~source tree in
  let* semantic = check_semantic_rules ~config ~context ~source tree in
  let* project_findings =
    Project_rules.check ~config ~context ~project ~source document
  in
  let* throws = check_throws ~config ~project ~source tree in
  let syntax = check_syntax_rules ~config ~source document in
  Ok
    (banned @ idioms @ syntax @ frameworks @ semantic @ project_findings
   @ throws)
