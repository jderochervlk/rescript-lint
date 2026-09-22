let strings values = `List (List.map (fun value -> `String value) values)
let optional encode = function None -> `Null | Some value -> encode value
let string value = `String value

let context = function
  | Policy_rules.Line -> "line"
  | Block -> "block"
  | Documentation -> "documentation"

let options (options : Project_options.t) =
  [
    ("root", optional string options.root);
    ( "jsxRuntime",
      optional
        (fun Project_options.React_dom -> string "react-dom")
        options.jsx_runtime );
    ( "testFramework",
      optional
        (fun Project_options.Rescript_vitest_3 -> string "rescript-vitest-3")
        options.test_framework );
    ( "throwsRuntime",
      optional
        (fun Project_options.Rescript_12_3_1 -> string "rescript-12.3.1")
        options.throws_runtime );
    ("throwsDependencies", strings options.throws_dependencies);
    ("restrictedModules", strings options.restricted_modules);
    ("restrictions", Restriction_policy.encode options.restrictions);
    ("entryModules", strings options.entry_modules);
    ("exclude", strings options.excluded_paths);
    ("license", string options.license);
    ("reanalyzeReport", optional string options.reanalyze_report);
    ("maxNesting", `Int options.limits.max_nesting);
    ("maxParams", `Int options.limits.max_params);
    ("maxLinesPerFunction", `Int options.limits.max_lines_per_function);
    ("maxNestedDescribe", `Int options.max_nested_describe);
    ("maxLines", `Int options.max_lines);
    ("maxSwitchCases", `Int options.max_switch_cases);
    ("deepEqualityThreshold", `Int options.deep_equality_threshold);
    ( "warningComments",
      `Assoc
        [
          ( "terms",
            strings (Policy_rules.warning_terms_config options.warning_comments)
          );
          ( "allowedContexts",
            strings
              (List.map context
                 (Policy_rules.warning_contexts_config options.warning_comments))
          );
        ] );
  ]

let requirements (options : Project_options.t) id =
  let jsx =
    Jsx_rules.rule_ids @ React_dom_rules.rule_ids
    @ React_semantic_rules.rule_ids
  in
  let configured name present =
    (name, if present then "configured" else "missing")
  in
  if List.mem id jsx then
    [ configured "jsxRuntime" (Option.is_some options.jsx_runtime) ]
  else if List.mem id Test_rules.rule_ids then
    [ configured "testFramework" (Option.is_some options.test_framework) ]
  else
    match id with
    | "require-interface" -> [ configured "root" (Option.is_some options.root) ]
    | "no-unused-export" ->
        [
          configured "root" (Option.is_some options.root);
          configured "reanalyzeReport" (Option.is_some options.reanalyze_report);
          ("fresh compiler artifacts and report", "not-checked");
        ]
    | "no-restricted-modules" ->
        [
          configured "restriction policy"
            (options.restricted_modules <> []
            || not (Restriction_policy.is_empty options.restrictions));
        ]
    | "no-unhandled-throws" when options.throws_dependencies <> [] ->
        [
          configured "root" (Option.is_some options.root);
          ("dependency declarations", "not-checked");
        ]
    | _ -> []

let rule ~filename config (rule : Rule_config.rule) =
  `Assoc
    [
      ("id", string rule.id);
      ("enabled", `Bool (Rule_config.enabled config rule.id));
      ("origin", string (Rule_config.rule_origin ~filename config rule.id));
      ( "requirements",
        `List
          (List.map
             (fun (name, status) ->
               `Assoc [ ("name", string name); ("status", string status) ])
             (requirements (Rule_config.options config) rule.id)) );
    ]

let describe ~filename config =
  let effective = Rule_config.for_file ~filename config in
  `Assoc
    [
      ("schemaVersion", `Int 1);
      ("filename", string filename);
      ("analysis", string "not-run");
      ("rules", `List (List.map (rule ~filename effective) Rule_config.rules));
      ("options", `Assoc (options (Rule_config.options effective)));
      ( "optionOrigins",
        `Assoc
          (List.map
             (fun (key, _) -> (key, string (Rule_config.origin config key)))
             (options (Rule_config.options effective))) );
    ]

let render_rule ~filename config (rule : Rule_config.rule) =
  let state =
    if Rule_config.enabled config rule.id then "enabled" else "disabled"
  in
  let requirements =
    requirements (Rule_config.options config) rule.id
    |> List.map (fun (name, status) -> name ^ ": " ^ status)
  in
  let suffix =
    match requirements with
    | [] -> ""
    | _ -> " [" ^ String.concat "; " requirements ^ "]"
  in
  Printf.sprintf "%s: %s (%s)%s" rule.id state
    (Rule_config.rule_origin ~filename config rule.id)
    suffix

let render ~filename config =
  let config = Rule_config.for_file ~filename config in
  String.concat "\n"
    ([ "Effective configuration: " ^ filename; "Analysis: not run" ]
    @ List.map (render_rule ~filename config) Rule_config.rules
    @ List.map
        (fun (key, value) ->
          Printf.sprintf "%s: %s (%s)" key
            (Yojson.Basic.to_string value)
            (Rule_config.origin config key))
        (options (Rule_config.options config)))
