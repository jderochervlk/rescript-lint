open Rescript_linter

let position = Diagnostic.{ line = 2; column = 3; byte_offset = 10 }

let diagnostic filename rule =
  Diagnostic.
    {
      filename;
      rule;
      message = "Forbidden API";
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

let run arguments = Application.run ~lint arguments

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
    ("help", (run [ "--help" ]).stdout = [ Command.help ]);
    ("short help", Command.parse [ "-h" ] = Ok Help);
    ("version", (run [ "--version" ]).stdout = [ Command.version ]);
    ("missing files", Command.parse [] = Error Missing_files);
    ("empty separator", Command.parse [ "--" ] = Error Missing_files);
    ( "unknown option",
      Command.parse [ "--wat" ] = Error (Unknown_option "--wat") );
    ( "option after file",
      Command.parse [ "clean.res"; "-x" ] = Error (Unknown_option "-x") );
    ("literal path", Command.parse [ "--"; "--help" ] = Ok (Lint [ "--help" ]));
    ( "file ordering",
      Command.parse [ "a.res"; "b.res"; "--"; "-c.res" ]
      = Ok (Lint [ "a.res"; "b.res"; "-c.res" ]) );
    ("clean exit", Application.exit_code (run [ "clean.res" ]).outcome = 0);
    ( "findings exit",
      Application.exit_code (run [ "bad.res"; "clean.res" ]).outcome = 1 );
    ( "failure exit",
      Application.exit_code (run [ "missing.res"; "bad.res" ]).outcome = 2 );
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
