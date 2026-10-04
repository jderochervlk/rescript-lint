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
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
