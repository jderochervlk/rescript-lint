open Rescript_linter

let diagnostic filename =
  Diagnostic.
    {
      filename;
      rule = "no-debugger";
      message = "Quoted \"text\"\nwith tab\tand UTF-8: \195\169";
      range =
        {
          start = { line = 2; column = 4; byte_offset = 12 };
          finish = { line = 3; column = 1; byte_offset = 25 };
        };
      fixes = [ { start = 12; finish = 25; text = "\"\195\169\"\n" } ];
    }

let lint = function
  | "clean.res" -> Ok []
  | "bad.res" -> Ok [ diagnostic "bad.res" ]
  | "parse.res" -> Error (Lint_error.Parse_errors (diagnostic "parse.res", []))
  | "analysis.res" ->
      Error
        (Lint_error.Analysis_errors
           (diagnostic "analysis.res", [ diagnostic "second.res" ]))
  | "write.res" ->
      Error
        (Lint_error.Write_error { filename = "write.res"; detail = "Denied" })
  | "fix.res" ->
      Error (Lint_error.Fix_error { filename = "fix.res"; detail = "Overlap" })
  | "bad.txt" -> Error (Lint_error.Unsupported_file "bad.txt")
  | filename -> Error (Lint_error.Read_error { filename; detail = "Missing" })

let run arguments =
  Application.run ~lint:(fun _ -> lint) ~fix:(fun _ _ -> Ok []) arguments

let json response =
  match response.Application.stdout with
  | [ text ] -> (
      try Some (Yojson.Basic.from_string text)
      with Yojson.Json_error _ -> None)
  | _ -> None

let field key = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt key fields)
  | _ -> `Null

let json_field key response = Option.map (field key) (json response)
let json_run files = run ([ "--format"; "json" ] @ files)

let first_diagnostic response =
  match json_field "diagnostics" response with
  | Some (`List [ diagnostic ]) -> diagnostic
  | _ -> `Null

let error_kind expected filename =
  let response = json_run [ filename ] in
  match json_field "errors" response with
  | Some (`List [ error ]) ->
      field "kind" error = `String expected
      && field "filename" error = `String filename
      && response.outcome = Failed && response.stderr = []
  | _ -> false

let command_failure arguments message =
  let response = json_run arguments in
  match json_field "errors" response with
  | Some (`List [ error ]) ->
      field "kind" error = `String "command"
      && field "filename" error = `Null
      && field "message" error = `String message
      && response.outcome = Failed
  | _ -> false

let checks =
  [
    ( "clean schema",
      json (json_run [ "clean.res" ])
      = Some
          (`Assoc
             [
               ("schemaVersion", `Int 1);
               ("outcome", `String "clean");
               ("exitCode", `Int 0);
               ("diagnostics", `List []);
               ("errors", `List []);
             ]) );
    ( "findings outcome and exit",
      let response = json_run [ "bad.res" ] in
      response.outcome = Findings
      && response.stderr = []
      && json_field "exitCode" response = Some (`Int 1)
      && json_field "outcome" response = Some (`String "findings") );
    ( "exact diagnostic and fixes",
      first_diagnostic (json_run [ "bad.res" ])
      = `Assoc
          [
            ("rule", `String "no-debugger");
            ("severity", `String "error");
            ("message", `String (diagnostic "bad.res").message);
            ("filename", `String "bad.res");
            ( "range",
              `Assoc
                [
                  ( "start",
                    `Assoc
                      [
                        ("line", `Int 2);
                        ("column", `Int 4);
                        ("byteOffset", `Int 12);
                      ] );
                  ( "end",
                    `Assoc
                      [
                        ("line", `Int 3);
                        ("column", `Int 1);
                        ("byteOffset", `Int 25);
                      ] );
                ] );
            ("help", `Null);
            ( "fixes",
              `List
                [
                  `Assoc
                    [
                      ("startByte", `Int 12);
                      ("endByte", `Int 25);
                      ("text", `String "\"\195\169\"\n");
                    ];
                ] );
          ] );
    ( "one physical output line",
      match (json_run [ "bad.res" ]).stdout with
      | [ line ] -> not (String.contains line '\n')
      | _ -> false );
    ( "empty fixes preserved",
      let found = { (diagnostic "empty.res") with fixes = [] } in
      let response =
        Application.run
          ~lint:(fun _ _ -> Ok [ found ])
          ~fix:(fun _ _ -> Ok [])
          [ "--format"; "json"; "empty.res" ]
      in
      field "fixes" (first_diagnostic response) = `List [] );
    ( "Unicode filename preserved",
      let filename = "\195\169\"\\.res" in
      let response =
        Application.run
          ~lint:(fun _ _ -> Ok [ diagnostic filename ])
          ~fix:(fun _ _ -> Ok [])
          [ "--format"; "json"; filename ]
      in
      field "filename" (first_diagnostic response) = `String filename );
    ("read error", error_kind "read" "missing.res");
    ("write error", error_kind "write" "write.res");
    ("fix error", error_kind "fix" "fix.res");
    ("unsupported file", error_kind "unsupported-file" "bad.txt");
    ("parse error", error_kind "parse" "parse.res");
    ("analysis error", error_kind "analysis" "analysis.res");
    ( "analysis diagnostic ordering",
      match json_field "errors" (json_run [ "analysis.res" ]) with
      | Some (`List [ error ]) -> (
          match field "diagnostics" error with
          | `List [ first; second ] ->
              field "filename" first = `String "analysis.res"
              && field "filename" second = `String "second.res"
          | _ -> false)
      | _ -> false );
    ( "mixed failure wins without dropping diagnostics",
      let response = json_run [ "bad.res"; "missing.res"; "clean.res" ] in
      response.outcome = Failed
      && json_field "outcome" response = Some (`String "failed")
      && json_field "exitCode" response = Some (`Int 2)
      && first_diagnostic response <> `Null );
    ( "failure first still retains findings",
      first_diagnostic (json_run [ "missing.res"; "bad.res" ]) <> `Null );
    ( "diagnostic ordering",
      let response =
        Application.run
          ~lint:(fun _ filename ->
            Ok [ diagnostic filename; diagnostic (filename ^ "2") ])
          ~fix:(fun _ _ -> Ok [])
          [ "--format"; "json"; "a.res"; "b.res" ]
      in
      match json_field "diagnostics" response with
      | Some (`List values) ->
          List.map (field "filename") values
          = List.map
              (fun value -> `String value)
              [ "a.res"; "a.res2"; "b.res"; "b.res2" ]
      | _ -> false );
    ( "error ordering",
      match json_field "errors" (json_run [ "first.res"; "second.res" ]) with
      | Some (`List errors) ->
          List.map (field "filename") errors
          = [ `String "first.res"; `String "second.res" ]
      | _ -> false );
    ("fix callback", (json_run [ "--fix"; "bad.res" ]).outcome = Clean);
    ("watch callback", (json_run [ "--watch"; "bad.res" ]).outcome = Findings);
    ( "watch fix callback",
      (json_run [ "--watch"; "--fix"; "bad.res" ]).outcome = Clean );
    ("missing files", command_failure [] "No input files. Use --help for usage.");
    ( "unknown option",
      command_failure [ "--unknown" ] "Unknown option: --unknown" );
    ( "missing format",
      command_failure [ "--format" ] "--format requires human or json." );
    ( "format cannot swallow flag",
      command_failure
        [ "--format"; "--fix"; "clean.res" ]
        "--format requires human or json." );
    ( "unsupported format",
      command_failure
        [ "--format"; "yaml"; "clean.res" ]
        "Unsupported output format: yaml" );
    ( "JSON rejects nonlint modes",
      List.for_all
        (fun arguments ->
          command_failure arguments
            "JSON output is supported only for lint, fix, and watch commands.")
        [
          [ "--help" ];
          [ "--version" ];
          [ "--list-rules" ];
          [ "lsp"; "--stdio" ];
        ] );
    ( "format after files",
      (run [ "bad.res"; "--format"; "json" ]).stdout
      = (json_run [ "bad.res" ]).stdout );
    ( "last format wins",
      (json_run [ "--format"; "human"; "bad.res" ]).stdout
      = (run [ "bad.res" ]).stdout );
    ( "format before malformed option still JSON",
      command_failure
        [ "--enable-rule"; "--fix" ]
        "--enable-rule requires a rule ID." );
    ( "valued option does not become a format",
      fst (Command.parse_with_format [ "--project"; "json"; "a.res" ]) = Human
    );
    ( "format removal cannot repair missing project value",
      command_failure
        [ "--project"; "--format"; "human"; "clean.res" ]
        "--project requires a value." );
    ( "format removal cannot repair missing rule value",
      command_failure
        [ "--enable-rule"; "--format"; "human"; "no-debugger"; "clean.res" ]
        "--enable-rule requires a rule ID." );
    ( "delimiter preserves format-like filenames",
      match Command.parse_with_format [ "--"; "--format"; "json" ] with
      | Human, Ok (Lint { files; _ }) -> files = [ "--format"; "json" ]
      | _ -> false );
    ( "human explicitly unchanged",
      run [ "--format"; "human"; "bad.res" ] = run [ "bad.res" ] );
    ( "invalid format defaults human error",
      (run [ "--format"; "xml"; "bad.res" ]).stderr
      = [ "Unsupported output format: xml" ] );
    ( "project input failure is structured",
      let response =
        json_run [ "--project"; "/nonexistent/json-project-test" ]
      in
      response.outcome = Failed && response.stderr = [] && json response <> None
    );
  ]

let () =
  let failed =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
