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
  match Command.parse arguments with
  | Ok (Lint { rules; _ } | Language_server rules) ->
      (Rule_config.options rules).throws_runtime = expected
  | _ -> false

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
      Command.parse [ "--throws-runtime"; "latest"; "a.res" ]
      = Error (Invalid_rule "Unsupported throwsRuntime.") );
    ( "missing throws runtime value",
      Command.parse [ "--throws-runtime" ]
      = Error (Invalid_rule "--throws-runtime requires a value.") );
    ( "throws runtime does not swallow flag",
      Command.parse [ "--throws-runtime"; "--fix"; "a.res" ]
      = Error (Invalid_rule "--throws-runtime requires a value.") );
    ( "throws runtime option follows file",
      throws_runtime_command (Some Rescript_12_3_1)
        [ "a.res"; "--throws-runtime"; "rescript-12.3.1" ] );
    ( "throws runtime option after terminator is literal",
      match Command.parse [ "--"; "--throws-runtime"; "rescript-12.3.1" ] with
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
      match Command.parse [ "--project"; "/project" ] with
      | Ok (Lint { files = []; _ }) -> true
      | _ -> false );
    ( "missing option value",
      match Command.parse [ "--jsx-runtime" ] with
      | Error _ -> true
      | _ -> false );
    ( "setting does not swallow flag",
      match Command.parse [ "--project"; "--fix"; "a.res" ] with
      | Error _ -> true
      | _ -> false );
    ( "adapter CLI",
      match
        Command.parse
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
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
