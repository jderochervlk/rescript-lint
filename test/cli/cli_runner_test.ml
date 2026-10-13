open Rescript_linter

let position = Diagnostic.{ line = 2; column = 3; byte_offset = 10 }

let diagnostic filename rule =
  Diagnostic.
    {
      filename;
      rule;
      message = "Forbidden API";
      help = None;
      symbol = None;
      fixes = [];
      range =
        {
          start = position;
          finish = { position with column = 9; byte_offset = 16 };
        };
    }

let lint = function
  | "clean.res" -> Ok []
  | "bad.res" ->
      Ok [ diagnostic "bad.res" "no-console"; diagnostic "bad.res" "no-unsafe" ]
  | filename -> Error (Lint_error.Read_error { filename; detail = "Missing" })

let run arguments =
  Cli_runner.run ~lint:(fun _ -> lint) ~fix:(fun _ _ -> Ok []) arguments

let request files = Cli_command.{ files; rules = Rule_config.default }

let execution_trace execute input =
  let calls = ref [] in
  let callback mode rules filename =
    calls := (mode, rules, filename) :: !calls;
    if mode = `Lint then lint filename else Ok []
  in
  let response = execute ~lint:(callback `Lint) ~fix:(callback `Fix) input in
  (response, List.rev !calls)

let equivalent arguments =
  execution_trace Cli_runner.run arguments
  = execution_trace Cli_runner.execute (Cli_command.parse_with_format arguments)

let with_config run =
  let filename = Filename.temp_file "cli-runner-config-" ".json" in
  let write enabled =
    Out_channel.with_open_bin filename (fun channel ->
        Printf.fprintf channel "{\"rules\":{\"no-console\":%b}}" enabled)
  in
  Fun.protect
    ~finally:(fun () -> Sys.remove filename)
    (fun () ->
      write false;
      run filename write)

let configuration_checks =
  with_config (fun filename write ->
      let arguments = [ "--config"; filename; "bad.res" ] in
      let decoded = Cli_command.parse_with_format arguments in
      write true;
      let selected_rules execute input =
        let _, calls = execution_trace execute input in
        List.map
          (fun (_, rules, _) -> Rule_config.enabled rules "no-console")
          calls
      in
      [
        ( "parsed execution retains decoded configuration",
          selected_rules Cli_runner.execute decoded = [ false ] );
        ( "argv wrapper reloads configuration for reruns",
          selected_rules Cli_runner.run arguments = [ true ] );
        ( "config and CLI precedence execution equivalence",
          equivalent
            [
              "--disable-rule";
              "no-console";
              "--config";
              filename;
              "--disable-rule";
              "no-console";
              "bad.res";
            ] );
      ])

let equivalence_checks =
  List.map
    (fun (name, arguments) ->
      ("parsed execution equivalence: " ^ name, equivalent arguments))
    [
      ("help", [ "--help" ]);
      ("version", [ "--version" ]);
      ("list rules", [ "--list-rules" ]);
      ("inspect config", [ "--inspect-config"; "bad.res" ]);
      ("lint", [ "bad.res"; "clean.res"; "missing.res" ]);
      ("fix", [ "--fix"; "bad.res"; "clean.res" ]);
      ("watch", [ "--watch"; "bad.res" ]);
      ("watch fix", [ "--watch"; "--fix"; "bad.res" ]);
      ("language server", [ "lsp"; "--stdio" ]);
      ("missing files", []);
      ("unknown option", [ "--wat" ]);
      ("missing rule", [ "--disable-rule"; "--fix"; "bad.res" ]);
      ("invalid rule", [ "--enable-rule"; "typo"; "bad.res" ]);
      ("literal filenames", [ "--"; "--help"; "--fix" ]);
      ( "rule precedence",
        [
          "--enable-rule";
          "no-console";
          "--disable-rule";
          "no-console";
          "bad.res";
        ] );
      ( "JSON inspect config",
        [ "--format"; "json"; "--inspect-config"; "bad.res" ] );
      ("JSON lint", [ "--format"; "json"; "bad.res"; "missing.res" ]);
      ("JSON fix", [ "--format"; "json"; "--fix"; "bad.res" ]);
      ("JSON watch", [ "--format"; "json"; "--watch"; "bad.res" ]);
      ("JSON watch fix", [ "--format"; "json"; "--watch"; "--fix"; "bad.res" ]);
      ("JSON command error", [ "--format"; "json"; "--wat" ]);
      ("JSON unsupported mode", [ "--format"; "json"; "--help" ]);
      ("invalid format", [ "--format"; "json"; "--format"; "typo" ]);
      ("missing format", [ "--format"; "json"; "--format" ]);
    ]

let checks =
  [
    ( "implementation source",
      Source.read "fixtures/example.res"
      = Ok
          Source.
            {
              filename = "fixtures/example.res";
              text = "let answer = 42\n";
              kind = Implementation;
            } );
    ( "interface source",
      Source.read "fixtures/example.resi"
      = Ok
          Source.
            {
              filename = "fixtures/example.resi";
              text = "let answer: int\n";
              kind = Interface;
            } );
    ("help", (run [ "--help" ]).stdout = [ Cli_command.help ]);
    ("short help", Cli_command.parse [ "-h" ] = Ok Help);
    ("version", (run [ "--version" ]).stdout = [ Cli_command.version ]);
    ( "language server",
      Cli_command.parse [ "lsp"; "--stdio" ]
      = Ok (Language_server Rule_config.default) );
    ( "language server needs stdio",
      Cli_command.parse [ "lsp" ] = Error Invalid_lsp_arguments );
    ( "fix command",
      Cli_command.parse [ "--fix"; "a.res" ] = Ok (Fix (request [ "a.res" ])) );
    ( "fix after file",
      Cli_command.parse [ "a.res"; "--fix" ] = Ok (Fix (request [ "a.res" ])) );
    ( "watch command",
      Cli_command.parse [ "--watch"; "a.res" ]
      = Ok
          (Watch
             { files = [ "a.res" ]; fix = false; rules = Rule_config.default })
    );
    ( "short watch command",
      Cli_command.parse [ "a.res"; "-w" ]
      = Ok
          (Watch
             { files = [ "a.res" ]; fix = false; rules = Rule_config.default })
    );
    ( "watch and fix command",
      Cli_command.parse [ "--watch"; "a.res"; "--fix" ]
      = Ok
          (Watch
             { files = [ "a.res" ]; fix = true; rules = Rule_config.default })
    );
    ("fix needs files", Cli_command.parse [ "--fix" ] = Error Missing_files);
    ("watch needs files", Cli_command.parse [ "--watch" ] = Error Missing_files);
    ( "fix literal path",
      Cli_command.parse [ "--fix"; "--"; "--fix" ]
      = Ok (Fix (request [ "--fix" ])) );
    ("fix callback", (run [ "--fix"; "bad.res" ]).outcome = Clean);
    ("watch lint callback", (run [ "--watch"; "bad.res" ]).outcome = Findings);
    ( "watch fix callback",
      (run [ "--watch"; "--fix"; "bad.res" ]).outcome = Clean );
    ("missing files", Cli_command.parse [] = Error Missing_files);
    ("empty separator", Cli_command.parse [ "--" ] = Error Missing_files);
    ( "unknown option",
      Cli_command.parse [ "--wat" ] = Error (Unknown_option "--wat") );
    ( "option after file",
      Cli_command.parse [ "clean.res"; "-x" ] = Error (Unknown_option "-x") );
    ( "literal path",
      Cli_command.parse [ "--"; "--help" ] = Ok (Lint (request [ "--help" ])) );
    ( "file ordering",
      Cli_command.parse [ "a.res"; "b.res"; "--"; "-c.res" ]
      = Ok (Lint (request [ "a.res"; "b.res"; "-c.res" ])) );
    ("clean exit", Cli_runner.exit_code (run [ "clean.res" ]).outcome = 0);
    ( "findings exit",
      Cli_runner.exit_code (run [ "bad.res"; "clean.res" ]).outcome = 1 );
    ( "failure exit",
      Cli_runner.exit_code (run [ "missing.res"; "bad.res" ]).outcome = 2 );
    ( "failure after findings",
      (run [ "bad.res"; "missing.res" ]).outcome = Failed );
    ( "failure survives clean",
      (run [ "missing.res"; "clean.res" ]).outcome = Failed );
    ( "usage error",
      (run []).stderr = [ "No input files. Use --help for usage." ] );
    ("option error", (run [ "-x" ]).stderr = [ "Unknown option: -x" ]);
    ( "diagnostic order",
      (run [ "bad.res" ]).stdout
      = [
          "bad.res:2:3: error [no-console] Forbidden API";
          "bad.res:2:3: error [no-unsafe] Forbidden API";
        ] );
    ( "continue after failure",
      (run [ "missing.res"; "bad.res" ]).stdout = (run [ "bad.res" ]).stdout );
    ( "failure order",
      (run [ "first.res"; "second.res" ]).stderr
      = [
          "first.res: Cannot read file: Missing";
          "second.res: Cannot read file: Missing";
        ] );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      (checks @ equivalence_checks @ configuration_checks)
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
