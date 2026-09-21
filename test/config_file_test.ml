open Rescript_linter

let decode json = Config_file.decode ~base:"/project" Rule_config.default json
let error = function Error _ -> true | Ok _ -> false

let options json predicate =
  match decode json with
  | Ok config -> predicate (Rule_config.options config)
  | Error _ -> false

let checks =
  [
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
