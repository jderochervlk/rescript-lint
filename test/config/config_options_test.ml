open Rescript_linter

let existing_options =
  Project_options.
    {
      default with
      jsx_runtime = Some React_dom;
      test_framework = Some Rescript_vitest_3;
      throws_runtime = Some Rescript_12_3_1;
      throws_dependencies = [ "/old/throws" ];
      root = Some "/old/root";
      restricted_modules = [ "OldRestricted" ];
      forbidden_source_roots = [ "/old/forbidden" ];
      source_root_dependencies = [ "/old/dependencies" ];
      entry_modules = [ "OldEntry" ];
      excluded_paths = [ "old/excluded" ];
      license = "Old-License";
      reanalyze_report = Some "/old/report.json";
      limits = { max_nesting = 7; max_params = 8; max_lines_per_function = 9 };
      max_nested_describe = 11;
      deep_equality_threshold = 12;
      max_lines = 13;
      max_switch_cases = 14;
    }

let existing_config =
  Rule_config.with_options existing_options Rule_config.default

let decode entries =
  Config_file.decode ~base:"/project" existing_config (`Assoc entries)

let changes_only key value expected =
  match decode [ (key, value) ] with
  | Ok config -> config = Rule_config.with_options expected existing_config
  | Error _ -> false

let adapter_changes =
  [
    ("jsxRuntime", `Null, { existing_options with jsx_runtime = None });
    ("testFramework", `Null, { existing_options with test_framework = None });
    ("throwsRuntime", `Null, { existing_options with throws_runtime = None });
    ("jsxRuntime", `String "react-dom", existing_options);
    ("testFramework", `String "rescript-vitest-3", existing_options);
    ("throwsRuntime", `String "rescript-12.3.1", existing_options);
  ]

let list_changes =
  let names = `List [ `String "Second"; `String "First" ] in
  let paths = `List [ `String "src/new"; `String "/shared" ] in
  let resolved = [ "/project/src/new"; "/shared" ] in
  [
    ( "restrictedModules",
      names,
      { existing_options with restricted_modules = [ "Second"; "First" ] } );
    ( "entryModules",
      names,
      { existing_options with entry_modules = [ "Second"; "First" ] } );
    ( "exclude",
      names,
      { existing_options with excluded_paths = [ "Second"; "First" ] } );
    ( "throwsDependencies",
      paths,
      { existing_options with throws_dependencies = resolved } );
    ( "forbiddenSourceRoots",
      paths,
      { existing_options with forbidden_source_roots = resolved } );
    ( "sourceRootDependencies",
      paths,
      { existing_options with source_root_dependencies = resolved } );
    ( "sourceRootDependencies",
      `List [],
      { existing_options with source_root_dependencies = [] } );
    ( "forbiddenSourceRoots",
      `List [],
      { existing_options with forbidden_source_roots = [] } );
  ]

let limit_changes =
  let limits = existing_options.limits in
  [
    ("maxLines", `Int 0, { existing_options with max_lines = 0 });
    ("maxSwitchCases", `Int 0, { existing_options with max_switch_cases = 0 });
    ( "maxNesting",
      `Int 0,
      { existing_options with limits = { limits with max_nesting = 0 } } );
    ( "maxParams",
      `Int 0,
      { existing_options with limits = { limits with max_params = 0 } } );
    ( "maxLinesPerFunction",
      `Int 0,
      {
        existing_options with
        limits = { limits with max_lines_per_function = 0 };
      } );
    ( "maxNestedDescribe",
      `Int 0,
      { existing_options with max_nested_describe = 0 } );
    ( "deepEqualityThreshold",
      `Int 2,
      { existing_options with deep_equality_threshold = 2 } );
  ]

let string_changes =
  [
    ("root", `String "src", { existing_options with root = Some "/project/src" });
    ("root", `String "/shared", { existing_options with root = Some "/shared" });
    ( "reanalyzeReport",
      `String "report.json",
      { existing_options with reanalyze_report = Some "/project/report.json" }
    );
    ( "reanalyzeReport",
      `String "/shared/report.json",
      { existing_options with reanalyze_report = Some "/shared/report.json" } );
    ( "license",
      `String " Apache-2.0 ",
      { existing_options with license = " Apache-2.0 " } );
  ]

let option_checks =
  List.map
    (fun (key, value, expected) ->
      ( "only " ^ key ^ " changes for " ^ Yojson.Basic.to_string value,
        changes_only key value expected ))
    (adapter_changes @ list_changes @ limit_changes @ string_changes)

let rejects key value message = decode [ (key, value) ] = Error message

let invalid_limits =
  List.concat_map
    (fun key ->
      List.map
        (fun value ->
          ( key ^ " rejects " ^ Yojson.Basic.to_string value,
            rejects key value "Expected a non-negative integer." ))
        [ `Int (-1); `String "1"; `Null; `Float 1.0 ])
    [
      "maxLines";
      "maxSwitchCases";
      "maxNesting";
      "maxParams";
      "maxLinesPerFunction";
      "maxNestedDescribe";
    ]

let invalid_adapters =
  List.map
    (fun key ->
      ( key ^ " rejects unknown names and wrong types",
        List.for_all
          (fun value -> rejects key value ("Unsupported " ^ key ^ "."))
          [ `String "generic"; `Bool false; `Int 1 ] ))
    [ "jsxRuntime"; "testFramework"; "throwsRuntime" ]

let invalid_lists =
  List.map
    (fun key ->
      ( key ^ " rejects non-string arrays",
        rejects key (`String "value") "Expected an array of strings."
        && rejects key (`List [ `String "first"; `Int 1 ]) "Expected a string."
      ))
    [
      "restrictedModules";
      "entryModules";
      "exclude";
      "throwsDependencies";
      "forbiddenSourceRoots";
      "sourceRootDependencies";
    ]

let invalid_strings =
  List.map
    (fun key ->
      ( key ^ " rejects blank and non-string values",
        rejects key (`String " \t ") (key ^ " must not be empty.")
        && rejects key `Null "Expected a string." ))
    [ "root"; "reanalyzeReport"; "license" ]

let policy_checks =
  let restrictions =
    `List
      [ `Assoc [ ("kind", `String "module"); ("path", `String "Internal") ] ]
  in
  [
    ( "only restrictions change",
      match Restriction_policy.decode restrictions with
      | Ok restrictions_value ->
          changes_only "restrictions" restrictions
            { existing_options with restrictions = restrictions_value }
      | Error _ -> false );
    ( "only warning comments change",
      match
        Policy_rules.warning_policy ~terms:[ "REVIEW" ]
          ~allowed_contexts:[ Block ]
      with
      | Ok warning_comments ->
          changes_only "warningComments"
            (`Assoc
               [
                 ("terms", `List [ `String "REVIEW" ]);
                 ("allowedContexts", `List [ `String "block" ]);
               ])
            { existing_options with warning_comments }
      | Error _ -> false );
    ( "warning policy errors are preserved",
      rejects "warningComments" `Null "warningComments must be an object." );
    ( "restriction policy errors are preserved",
      rejects "restrictions" `Null "restrictions must be an array." );
  ]

let checks =
  option_checks @ invalid_limits @ invalid_adapters @ invalid_lists
  @ invalid_strings @ policy_checks
  @ [
      ( "empty config preserves existing settings",
        decode [] = Ok existing_config );
      ( "unknown option error",
        rejects "maxLine" (`Int 0) "Unknown configuration property: maxLine" );
      ( "deep equality threshold rejects values below two and wrong types",
        List.for_all
          (fun value ->
            rejects "deepEqualityThreshold" value
              "deepEqualityThreshold must be an integer of at least 2.")
          [ `Int 1; `Int (-1); `String "2"; `Null ] );
      ( "path lists reject blank entries",
        List.for_all
          (fun key ->
            rejects key
              (`List [ `String "valid"; `String " " ])
              "Paths must not be empty.")
          [
            "throwsDependencies";
            "forbiddenSourceRoots";
            "sourceRootDependencies";
          ] );
      ( "entries apply in order and the first error is retained",
        decode [ ("maxLines", `Int (-1)); ("typo", `Bool true) ]
        = Error "Expected a non-negative integer." );
      ( "multiple limits preserve nested settings",
        match decode [ ("maxNesting", `Int 2); ("maxParams", `Int 3) ] with
        | Ok config ->
            config
            = Rule_config.with_options
                {
                  existing_options with
                  limits =
                    {
                      existing_options.limits with
                      max_nesting = 2;
                      max_params = 3;
                    };
                }
                existing_config
        | Error _ -> false );
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
