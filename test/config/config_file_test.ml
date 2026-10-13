open Rescript_linter

let decode json = Config_file.decode ~base:"/project" Rule_config.default json
let error = function Error _ -> true | Ok _ -> false

let options json predicate =
  match decode json with
  | Ok config -> predicate (Rule_config.options config)
  | Error _ -> false

let with_config json check =
  try
    let filename = Filename.temp_file "rescript-lint-config-" ".json" in
    Fun.protect
      ~finally:(fun () -> Sys.remove filename)
      (fun () ->
        Yojson.Basic.to_file filename json;
        check filename)
  with Sys_error _ -> false

let throws_runtime_command expected arguments =
  match Cli_command.parse arguments with
  | Ok (Lint { rules; _ } | Language_server rules) ->
      (Rule_config.options rules).throws_runtime = expected
  | _ -> false

let get_ok = function Ok value -> value | Error message -> failwith message

(* Compare the complete record, including non-default unrelated settings. *)
let property_cases =
  let strings = `List [ `String "Second"; `String "First" ] in
  let paths = `List [ `String "src/second"; `String "/shared/first" ] in
  let resolved = [ "/project/src/second"; "/shared/first" ] in
  let restrictions_json =
    `List [ `Assoc [ ("kind", `String "module"); ("path", `String "Private") ] ]
  in
  let restrictions = get_ok (Restriction_policy.decode restrictions_json) in
  let warning_comments =
    get_ok
      (Policy_rules.warning_policy ~terms:[ "FIXME" ] ~allowed_contexts:[ Line ])
  in
  [
    ( "jsxRuntime",
      `String "react-dom",
      fun (options : Project_options.t) ->
        { options with jsx_runtime = Some React_dom } );
    ( "testFramework",
      `String "rescript-vitest-3",
      fun (options : Project_options.t) ->
        { options with test_framework = Some Rescript_vitest_3 } );
    ( "throwsRuntime",
      `String "rescript-12.3.1",
      fun (options : Project_options.t) ->
        { options with throws_runtime = Some Rescript_12_3_1 } );
    ( "restrictedModules",
      strings,
      fun (options : Project_options.t) ->
        { options with restricted_modules = [ "Second"; "First" ] } );
    ( "entryModules",
      strings,
      fun (options : Project_options.t) ->
        { options with entry_modules = [ "Second"; "First" ] } );
    ( "exclude",
      strings,
      fun (options : Project_options.t) ->
        { options with excluded_paths = [ "Second"; "First" ] } );
    ( "throwsDependencies",
      paths,
      fun (options : Project_options.t) ->
        { options with throws_dependencies = resolved } );
    ( "forbiddenSourceRoots",
      paths,
      fun (options : Project_options.t) ->
        { options with forbidden_source_roots = resolved } );
    ( "sourceRootDependencies",
      paths,
      fun (options : Project_options.t) ->
        { options with source_root_dependencies = resolved } );
    ( "maxLines",
      `Int 7,
      fun (options : Project_options.t) -> { options with max_lines = 7 } );
    ( "maxSwitchCases",
      `Int 7,
      fun (options : Project_options.t) -> { options with max_switch_cases = 7 }
    );
    ( "maxNestedDescribe",
      `Int 7,
      fun (options : Project_options.t) ->
        { options with max_nested_describe = 7 } );
    ( "deepEqualityThreshold",
      `Int 7,
      fun (options : Project_options.t) ->
        { options with deep_equality_threshold = 7 } );
    ( "maxNesting",
      `Int 7,
      fun (options : Project_options.t) ->
        { options with limits = { options.limits with max_nesting = 7 } } );
    ( "maxParams",
      `Int 7,
      fun (options : Project_options.t) ->
        { options with limits = { options.limits with max_params = 7 } } );
    ( "maxLinesPerFunction",
      `Int 7,
      fun (options : Project_options.t) ->
        {
          options with
          limits = { options.limits with max_lines_per_function = 7 };
        } );
    ( "root",
      `String "src",
      fun (options : Project_options.t) ->
        { options with root = Some "/project/src" } );
    ( "reanalyzeReport",
      `String "report.json",
      fun (options : Project_options.t) ->
        { options with reanalyze_report = Some "/project/report.json" } );
    ( "license",
      `String "Apache-2.0",
      fun (options : Project_options.t) ->
        { options with license = "Apache-2.0" } );
    ( "restrictions",
      restrictions_json,
      fun (options : Project_options.t) -> { options with restrictions } );
    ( "warningComments",
      `Assoc
        [
          ("terms", `List [ `String "FIXME" ]);
          ("allowedContexts", `List [ `String "line" ]);
        ],
      fun (options : Project_options.t) -> { options with warning_comments } );
  ]

let seeded_options =
  List.fold_left
    (fun options (_, _, update) -> update options)
    Project_options.default property_cases

let seeded_config = Rule_config.with_options seeded_options Rule_config.default

let isolated_property_checks =
  List.concat_map
    (fun (key, value, update) ->
      List.map
        (fun initial ->
          ( "isolated property " ^ key,
            match
              Config_file.decode ~base:"/project"
                (Rule_config.with_options initial Rule_config.default)
                (`Assoc [ (key, value) ])
            with
            | Ok config ->
                Rule_config.options config = update initial
                && Rule_config.enabled_ids config
                   = Rule_config.enabled_ids Rule_config.default
            | Error _ -> false ))
        [
          Project_options.default;
          { seeded_options with license = "BSD-3-Clause" };
        ])
    property_cases

let invalid_property_checks =
  let cases =
    List.map
      (fun key -> (key, "Expected an array of strings."))
      [
        "restrictedModules";
        "entryModules";
        "exclude";
        "throwsDependencies";
        "forbiddenSourceRoots";
        "sourceRootDependencies";
      ]
    @ List.map
        (fun key -> (key, "Expected a non-negative integer."))
        [
          "maxLines";
          "maxSwitchCases";
          "maxNesting";
          "maxParams";
          "maxLinesPerFunction";
          "maxNestedDescribe";
        ]
    @ List.map
        (fun key -> (key, "Expected a string."))
        [ "root"; "reanalyzeReport"; "license" ]
    @ List.map
        (fun key -> (key, "Unsupported " ^ key ^ "."))
        [ "jsxRuntime"; "testFramework"; "throwsRuntime" ]
    @ [
        ( "deepEqualityThreshold",
          "deepEqualityThreshold must be an integer of at least 2." );
        ("restrictions", "restrictions must be an array.");
        ("warningComments", "warningComments must be an object.");
      ]
  in
  List.map
    (fun (key, message) ->
      ( "malformed property " ^ key,
        Config_file.decode ~base:"/project" seeded_config
          (`Assoc [ (key, `Bool true) ])
        = Error message ))
    cases

let adapter_reset_checks =
  List.map
    (fun (key, reset) ->
      ( "isolated null reset " ^ key,
        match
          Config_file.decode ~base:"/project" seeded_config
            (`Assoc [ (key, `Null) ])
        with
        | Ok config -> Rule_config.options config = reset seeded_options
        | Error _ -> false ))
    [
      ( "jsxRuntime",
        fun (options : Project_options.t) -> { options with jsx_runtime = None }
      );
      ("testFramework", fun options -> { options with test_framework = None });
      ("throwsRuntime", fun options -> { options with throws_runtime = None });
    ]

let cli_setting_checks =
  List.concat_map
    (fun (flag, key, value, update) ->
      let parse arguments expected origin =
        match Cli_command.parse (arguments @ [ "a.res"; "b.res" ]) with
        | Ok (Lint { files; rules }) ->
            files = [ "a.res"; "b.res" ]
            && Rule_config.options rules = expected
            && Rule_config.origin rules key = origin
        | _ -> false
      in
      [
        ( "isolated CLI " ^ flag,
          parse [ flag; value ] (update Project_options.default) ("CLI " ^ flag)
        );
        ( "missing CLI value " ^ flag,
          Cli_command.parse [ flag ]
          = Error (Invalid_rule (flag ^ " requires a value."))
          && Cli_command.parse [ flag; "--fix" ]
             = Error (Invalid_rule (flag ^ " requires a value.")) );
        ( "CLI overrides config " ^ flag,
          with_config
            (`Assoc
               (List.map (fun (key, value, _) -> (key, value)) property_cases))
            (fun filename ->
              let loaded =
                get_ok (Config_file.load Rule_config.default filename)
              in
              parse
                [ "--config"; filename; flag; value ]
                (update (Rule_config.options loaded))
                ("CLI " ^ flag)) );
        ( "config overrides CLI " ^ flag,
          with_config
            (`Assoc
               (List.map (fun (key, value, _) -> (key, value)) property_cases))
            (fun filename ->
              let loaded =
                get_ok (Config_file.load Rule_config.default filename)
              in
              parse
                [ flag; value; "--config"; filename ]
                (Rule_config.options loaded)
                filename) );
      ])
    [
      ( "--project",
        "root",
        "cli-src",
        fun (options : Project_options.t) ->
          { options with root = Some "./cli-src" } );
      ( "--jsx-runtime",
        "jsxRuntime",
        "react-dom",
        fun options -> { options with jsx_runtime = Some React_dom } );
      ( "--test-framework",
        "testFramework",
        "rescript-vitest-3",
        fun options -> { options with test_framework = Some Rescript_vitest_3 }
      );
      ( "--throws-runtime",
        "throwsRuntime",
        "rescript-12.3.1",
        fun options -> { options with throws_runtime = Some Rescript_12_3_1 } );
    ]

let dispatch_error_checks =
  List.map
    (fun key ->
      ( "unknown property " ^ key,
        Config_file.decode ~base:"/project" seeded_config
          (`Assoc [ (key, `String "value") ])
        = Error ("Unknown configuration property: " ^ key) ))
    [ "excludedPaths"; "maxNestedDescribes"; "licence"; "testFrameWork" ]
  @ List.map
      (fun (key, value, _) ->
        ( "duplicate property " ^ key,
          Config_file.decode ~base:"/project" seeded_config
            (`Assoc [ (key, value); (key, value) ])
          = Error "Duplicate configuration properties are not allowed." ))
      property_cases
  @ [
      ( "unknown CLI cannot select test adapter",
        Cli_command.parse [ "--test-framewrok"; "rescript-vitest-3"; "a.res" ]
        = Error (Unknown_option "--test-framewrok") );
    ]

let checks =
  [
    ( "dependency contracts opt-in",
      Project_options.default.throws_dependencies = [] );
    ( "dependency paths relative to config",
      options
        (`Assoc
           [
             ( "throwsDependencies",
               `List [ `String "node_modules/pkg"; `String "/shared/pkg" ] );
           ])
        (fun options ->
          options.throws_dependencies
          = [ "/project/node_modules/pkg"; "/shared/pkg" ]) );
    ( "dependency paths array required",
      error (decode (`Assoc [ ("throwsDependencies", `String "pkg") ])) );
    ( "dependency paths string elements required",
      error (decode (`Assoc [ ("throwsDependencies", `List [ `Int 1 ]) ])) );
    ( "empty dependency path rejected",
      error (decode (`Assoc [ ("throwsDependencies", `List [ `String " " ]) ]))
    );
    ( "dependency paths may be cleared",
      match
        decode (`Assoc [ ("throwsDependencies", `List [ `String "pkg" ]) ])
      with
      | Error _ -> false
      | Ok config -> (
          match
            Config_file.decode ~base:"." config
              (`Assoc [ ("throwsDependencies", `List []) ])
          with
          | Error _ -> false
          | Ok config -> (Rule_config.options config).throws_dependencies = [])
    );
    ( "source-root paths relative to config",
      options
        (`Assoc
           [
             ("forbiddenSourceRoots", `List [ `String "src/internal" ]);
             ("sourceRootDependencies", `List [ `String "../shared" ]);
           ])
        (fun options ->
          options.forbidden_source_roots = [ "/project/src/internal" ]
          && options.source_root_dependencies = [ "/project/../shared" ]) );
    ( "source-root arrays required",
      error
        (decode (`Assoc [ ("forbiddenSourceRoots", `String "src/internal") ]))
      && error
           (decode (`Assoc [ ("sourceRootDependencies", `List [ `Int 1 ]) ])) );
    ( "source-root empty path rejected",
      error (decode (`Assoc [ ("forbiddenSourceRoots", `List [ `String "" ]) ]))
    );
    ( "throws runtime disabled by default",
      Project_options.default.throws_runtime = None );
    ( "throws runtime adapter",
      options
        (`Assoc [ ("throwsRuntime", `String "rescript-12.3.1") ])
        (fun options -> options.throws_runtime = Some Rescript_12_3_1) );
    ( "null throws runtime",
      options
        (`Assoc [ ("throwsRuntime", `Null) ])
        (fun options -> options.throws_runtime = None) );
    ( "unsupported throws runtime",
      error (decode (`Assoc [ ("throwsRuntime", `String "rescript-12.3.0") ]))
    );
    ( "throws runtime is case sensitive",
      error (decode (`Assoc [ ("throwsRuntime", `String "ReScript-12.3.1") ]))
    );
    ( "throws runtime rejects nonstrings",
      List.for_all
        (fun value -> error (decode (`Assoc [ ("throwsRuntime", value) ])))
        [ `Bool true; `Int 12; `List []; `Assoc [] ] );
    ( "throws runtime CLI",
      throws_runtime_command (Some Rescript_12_3_1)
        [ "--throws-runtime"; "rescript-12.3.1"; "a.res" ] );
    ( "unsupported throws runtime CLI",
      Cli_command.parse [ "--throws-runtime"; "latest"; "a.res" ]
      = Error (Invalid_rule "Unsupported throwsRuntime.") );
    ( "missing throws runtime value",
      Cli_command.parse [ "--throws-runtime" ]
      = Error (Invalid_rule "--throws-runtime requires a value.") );
    ( "throws runtime does not swallow flag",
      Cli_command.parse [ "--throws-runtime"; "--fix"; "a.res" ]
      = Error (Invalid_rule "--throws-runtime requires a value.") );
    ( "throws runtime option follows file",
      throws_runtime_command (Some Rescript_12_3_1)
        [ "a.res"; "--throws-runtime"; "rescript-12.3.1" ] );
    ( "throws runtime option after terminator is literal",
      match
        Cli_command.parse [ "--"; "--throws-runtime"; "rescript-12.3.1" ]
      with
      | Ok (Lint { files; rules }) ->
          files = [ "--throws-runtime"; "rescript-12.3.1" ]
          && (Rule_config.options rules).throws_runtime = None
      | _ -> false );
    ( "later config clears throws runtime",
      with_config
        (`Assoc [ ("throwsRuntime", `Null) ])
        (fun filename ->
          throws_runtime_command None
            [
              "--throws-runtime";
              "rescript-12.3.1";
              "--config";
              filename;
              "a.res";
            ]) );
    ( "later CLI enables throws runtime",
      with_config
        (`Assoc [ ("throwsRuntime", `Null) ])
        (fun filename ->
          throws_runtime_command (Some Rescript_12_3_1)
            [
              "--config";
              filename;
              "--throws-runtime";
              "rescript-12.3.1";
              "a.res";
            ]) );
    ( "LSP throws runtime CLI",
      throws_runtime_command (Some Rescript_12_3_1)
        [ "lsp"; "--stdio"; "--throws-runtime"; "rescript-12.3.1" ] );
    ( "LSP throws runtime config",
      with_config
        (`Assoc [ ("throwsRuntime", `String "rescript-12.3.1") ])
        (fun filename ->
          throws_runtime_command (Some Rescript_12_3_1)
            [ "--config"; filename; "lsp"; "--stdio" ]) );
    ( "throws runtime preserves other adapters",
      options
        (`Assoc
           [
             ("jsxRuntime", `String "react-dom");
             ("testFramework", `String "rescript-vitest-3");
             ("throwsRuntime", `String "rescript-12.3.1");
           ])
        (fun options ->
          options.jsx_runtime = Some React_dom
          && options.test_framework = Some Rescript_vitest_3
          && options.throws_runtime = Some Rescript_12_3_1) );
    ( "deep equality threshold",
      options
        (`Assoc [ ("deepEqualityThreshold", `Int 2) ])
        (fun options -> options.deep_equality_threshold = 2) );
    ( "invalid deep equality threshold",
      error (decode (`Assoc [ ("deepEqualityThreshold", `Int 1) ])) );
    ("empty config", decode (`Assoc []) = Ok Rule_config.default);
    ( "root relative",
      options
        (`Assoc [ ("root", `String "src") ])
        (fun options -> options.root = Some "/project/src") );
    ( "root absolute",
      options
        (`Assoc [ ("root", `String "/work") ])
        (fun options -> options.root = Some "/work") );
    ( "report relative",
      options
        (`Assoc [ ("reanalyzeReport", `String "dead.json") ])
        (fun options -> options.reanalyze_report = Some "/project/dead.json") );
    ( "license",
      options
        (`Assoc [ ("license", `String "Apache-2.0") ])
        (fun options -> options.license = "Apache-2.0") );
    ( "jsx adapter",
      options
        (`Assoc [ ("jsxRuntime", `String "react-dom") ])
        (fun options -> options.jsx_runtime = Some React_dom) );
    ( "test adapter",
      options
        (`Assoc [ ("testFramework", `String "rescript-vitest-3") ])
        (fun options -> options.test_framework = Some Rescript_vitest_3) );
    ( "null adapter",
      options
        (`Assoc [ ("jsxRuntime", `Null); ("testFramework", `Null) ])
        (fun options ->
          options.jsx_runtime = None && options.test_framework = None) );
    ( "unknown adapter",
      error (decode (`Assoc [ ("jsxRuntime", `String "generic") ])) );
    ( "enable",
      match
        decode
          (`Assoc [ ("rules", `Assoc [ ("jsx-a11y/alt-text", `Bool true) ]) ])
      with
      | Ok config -> Rule_config.enabled config "jsx-a11y/alt-text"
      | _ -> false );
    ( "disable",
      match
        decode (`Assoc [ ("rules", `Assoc [ ("no-console", `Bool false) ]) ])
      with
      | Ok config -> not (Rule_config.enabled config "no-console")
      | _ -> false );
    ( "unknown rule",
      error
        (decode (`Assoc [ ("rules", `Assoc [ ("no-such-rule", `Bool true) ]) ]))
    );
    ( "severity not accepted",
      error
        (decode
           (`Assoc [ ("rules", `Assoc [ ("no-console", `String "warn") ]) ])) );
    ("rules must object", error (decode (`Assoc [ ("rules", `List []) ])));
    ("object required", error (decode (`List [])));
    ("unknown key", error (decode (`Assoc [ ("typo", `Bool true) ])));
    ( "duplicate key",
      error (decode (`Assoc [ ("root", `String "a"); ("root", `String "b") ]))
    );
    ( "duplicate rule",
      error
        (decode
           (`Assoc
              [
                ( "rules",
                  `Assoc
                    [ ("no-console", `Bool true); ("no-console", `Bool false) ]
                );
              ])) );
    ("empty path", error (decode (`Assoc [ ("root", `String " ") ])));
    ("invalid string", error (decode (`Assoc [ ("license", `Bool false) ])));
    ( "lists",
      options
        (`Assoc
           [
             ("restrictedModules", `List [ `String "Database" ]);
             ("entryModules", `List [ `String "Main" ]);
             ("exclude", `List [ `String "src/generated" ]);
           ])
        (fun options ->
          options.restricted_modules = [ "Database" ]
          && options.entry_modules = [ "Main" ]
          && options.excluded_paths = [ "src/generated" ]) );
    ( "list invalid member",
      error (decode (`Assoc [ ("exclude", `List [ `Int 1 ]) ])) );
    ("list required", error (decode (`Assoc [ ("exclude", `String "src") ])));
    ( "limits",
      options
        (`Assoc
           [
             ("maxNesting", `Int 2);
             ("maxParams", `Int 3);
             ("maxLinesPerFunction", `Int 9);
             ("maxNestedDescribe", `Int 1);
           ])
        (fun options ->
          options.limits
          = { max_nesting = 2; max_params = 3; max_lines_per_function = 9 }
          && options.max_nested_describe = 1) );
    ("negative limit", error (decode (`Assoc [ ("maxParams", `Int (-1)) ])));
    ("wrong limit type", error (decode (`Assoc [ ("maxParams", `String "2") ])));
    ( "missing config",
      error
        (Config_file.load Rule_config.default
           "/nonexistent/rescript-lint-config.json") );
    ( "project needs no explicit files",
      match Cli_command.parse [ "--project"; "/project" ] with
      | Ok (Lint { files = []; _ }) -> true
      | _ -> false );
    ( "missing option value",
      match Cli_command.parse [ "--jsx-runtime" ] with
      | Error _ -> true
      | _ -> false );
    ( "setting does not swallow flag",
      match Cli_command.parse [ "--project"; "--fix"; "a.res" ] with
      | Error _ -> true
      | _ -> false );
    ( "adapter CLI",
      match
        Cli_command.parse
          [
            "--jsx-runtime";
            "react-dom";
            "--test-framework";
            "rescript-vitest-3";
            "a.res";
          ]
      with
      | Ok (Lint { rules; _ }) ->
          (Rule_config.options rules).jsx_runtime = Some React_dom
      | _ -> false );
  ]

let () =
  let failed =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      (checks @ isolated_property_checks @ invalid_property_checks
     @ adapter_reset_checks @ cli_setting_checks @ dispatch_error_checks)
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
