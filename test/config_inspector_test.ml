open Rescript_linter

let member key = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt key fields)
  | _ -> `Null

let list = function `List values -> values | _ -> []

let run args =
  Application.run
    ~lint:(fun _ _ -> Error (Lint_error.Unsupported_file "called lint"))
    ~fix:(fun _ _ -> Error (Lint_error.Unsupported_file "called fix"))
    args

let inspect args =
  match
    (run
       ("--format" :: "json" :: "--inspect-config" :: "/repo/src/A.res" :: args))
      .stdout
  with
  | [ json ] -> Yojson.Basic.from_string json
  | _ -> `Null

let find_rule id report =
  member "rules" report |> list
  |> List.find_opt (fun rule -> member "id" rule = `String id)

let rule_field id field report =
  Option.fold ~none:`Null ~some:(member field) (find_rule id report)

let decode value = Config_file.decode ~base:"/repo" Rule_config.default value

let checks =
  [
    ( "complete schema fixture",
      Result.is_ok
        (Config_file.load Rule_config.default
           "fixtures/config-schema-valid.json") );
    ( "invalid schema fixture",
      Result.is_error
        (Config_file.load Rule_config.default
           "fixtures/config-schema-invalid.json") );
    ( "literal inspect filename",
      match Command.parse [ "--"; "--inspect-config" ] with
      | Ok (Lint { files = [ "--inspect-config" ]; _ }) -> true
      | _ -> false );
    ( "size options",
      match
        decode (`Assoc [ ("maxLines", `Int 0); ("maxSwitchCases", `Int 3) ])
      with
      | Ok rules ->
          let options = Rule_config.options rules in
          options.max_lines = 0 && options.max_switch_cases = 3
      | _ -> false );
    ( "invalid size",
      Result.is_error (decode (`Assoc [ ("maxLines", `Int (-1)) ])) );
    ( "invalid case count",
      Result.is_error (decode (`Assoc [ ("maxSwitchCases", `String "3") ])) );
    ( "read-only inspection",
      (run [ "--inspect-config"; "missing.res" ]).outcome = Clean );
    ( "human output",
      match (run [ "--inspect-config"; "missing.res" ]).stdout with
      | [ text ] ->
          String.starts_with ~prefix:"Effective configuration: missing.res" text
      | _ -> false );
    ("defaults", rule_field "no-console" "enabled" (inspect []) = `Bool true);
    ( "default origin",
      rule_field "no-console" "origin" (inspect []) = `String "default" );
    ( "CLI state",
      rule_field "no-console" "enabled"
        (inspect [ "--disable-rule"; "no-console" ])
      = `Bool false );
    ( "CLI origin",
      rule_field "no-console" "origin"
        (inspect [ "--disable-rule"; "no-console" ])
      = `String "CLI --disable-rule" );
    ( "options",
      member "root" (member "options" (inspect [ "--project"; "/repo" ]))
      = `String "/repo" );
    ( "option origin",
      member "root" (member "optionOrigins" (inspect [ "--project"; "/repo" ]))
      = `String "CLI --project" );
    ( "missing adapter",
      rule_field "jsx-a11y/alt-text" "requirements" (inspect [])
      = `List
          [
            `Assoc
              [ ("name", `String "jsxRuntime"); ("status", `String "missing") ];
          ] );
    ( "configured adapter",
      rule_field "test/no-focused-tests" "requirements"
        (inspect [ "--test-framework"; "rescript-vitest-3" ])
      = `List
          [
            `Assoc
              [
                ("name", `String "testFramework");
                ("status", `String "configured");
              ];
          ] );
    ("no analysis claim", member "analysis" (inspect []) = `String "not-run");
    ( "schema metadata",
      Result.is_ok (decode (`Assoc [ ("$schema", `String "not-fetched") ])) );
    ( "invalid schema metadata",
      Result.is_error (decode (`Assoc [ ("$schema", `Int 1) ])) );
    ( "duplicate schema",
      Result.is_error
        (decode (`Assoc [ ("$schema", `String "a"); ("$schema", `String "b") ]))
    );
    ( "schema registry",
      let schema_rules =
        member "properties"
          (member "rules" (member "properties" Config_schema.document))
      in
      match schema_rules with
      | `Assoc fields ->
          List.map fst fields
          = List.map (fun (r : Rule_config.rule) -> r.id) Rule_config.rules
      | _ -> false );
    ( "shipped schema",
      Yojson.Basic.from_file "../npm/config.schema.json"
      = Config_schema.document );
  ]

let with_config test =
  let filename = Filename.temp_file "lint-inspect" ".json" in
  Fun.protect
    ~finally:(fun () -> Sys.remove filename)
    (fun () ->
      Yojson.Basic.to_file filename
        (`Assoc
           [
             ("rules", `Assoc [ ("no-console", `Bool false) ]);
             ( "overrides",
               `List
                 [
                   `Assoc
                     [
                       ("paths", `List [ `String "/repo/src" ]);
                       ("rules", `Assoc [ ("no-console", `Bool true) ]);
                     ];
                 ] );
             ( "warningComments",
               `Assoc
                 [
                   ( "allowedContexts",
                     `List
                       [
                         `String "line";
                         `String "block";
                         `String "documentation";
                       ] );
                 ] );
             ("throwsDependencies", `List [ `String "deps" ]);
             ("root", `String "/repo");
             ("reanalyzeReport", `String "report.json");
             ("restrictedModules", `List [ `String "Array" ]);
           ]);
      test filename)

let file_checks =
  with_config (fun filename ->
      let report =
        inspect
          [
            "--config";
            filename;
            "--disable-rule";
            "no-console";
            "--jsx-runtime";
            "react-dom";
            "--throws-runtime";
            "rescript-12.3.1";
          ]
      in
      [
        ( "override wins over CLI base",
          rule_field "no-console" "enabled" report = `Bool true );
        ( "override origin",
          rule_field "no-console" "origin" report
          = `String (filename ^ " overrides[0]") );
        ( "loaded option origin",
          member "root" (member "optionOrigins" report) = `String filename );
        ( "CLI replaces config base",
          let r =
            run
              [
                "--config";
                filename;
                "--enable-rule";
                "no-console";
                "--inspect-config";
                "/other.res";
              ]
          in
          r.outcome = Clean );
        ( "loaded rule origin",
          match
            Command.parse
              [ "--config"; filename; "--inspect-config"; "/other.res" ]
          with
          | Ok (Inspect_config { rules; filename = target }) ->
              Rule_config.rule_origin ~filename:target rules "no-console"
              = filename
          | _ -> false );
      ])

let invalid =
  List.map
    (fun args -> (String.concat " " args, (run args).outcome = Failed))
    [
      [ "--inspect-config" ];
      [ "--inspect-config"; "--fix" ];
      [ "--inspect-config"; "a.res"; "b.res" ];
      [ "--fix"; "--inspect-config"; "a.res" ];
      [ "--watch"; "--inspect-config"; "a.res" ];
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      (checks @ file_checks @ invalid)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
