open Rescript_linter

let error = function Error _ -> true | Ok _ -> false

let write path text =
  Out_channel.with_open_bin path (fun channel -> output_string channel text)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  let root = Filename.temp_file "linter-errors-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let source ?(kind = Source.Implementation) filename text =
  Source.{ filename; kind; text }

let config id options =
  Rule_config.set
    (Rule_config.with_options options Rule_config.default)
    ~id ~enabled:true

let lint id options source =
  Result.bind (config id options) (fun config ->
      Result.map_error Lint_error.render
        (Linter.lint_source_with_rules config source))

let has id = function
  | Ok findings ->
      List.exists (fun finding -> finding.Diagnostic.rule = id) findings
  | Error _ -> false

let local =
  [
    ( "JSX adapter required",
      error
        (lint "jsx-a11y/alt-text" Project_options.default
           (source "x.res" "let x = <img />")) );
    ( "test adapter required",
      error
        (lint "test/no-focused-tests" Project_options.default
           (source "x.res" "Vitest.Test.testOnly(\"x\", t => ())")) );
    ( "JSX adapter selected",
      has "jsx-a11y/alt-text"
        (lint "jsx-a11y/alt-text"
           { Project_options.default with jsx_runtime = Some React_dom }
           (source "x.res" "let x = <img />")) );
    ( "test adapter selected",
      has "test/no-focused-tests"
        (lint "test/no-focused-tests"
           {
             Project_options.default with
             test_framework = Some Rescript_vitest_3;
           }
           (source "x.res" "Vitest.test(\"x\", ~only=true, _ => ())")) );
    ( "semantic enabled",
      has "require-await"
        (lint "require-await" Project_options.default
           (source "x.res" "let run = async () => 1")) );
    ( "semantic uncertainty",
      error
        (lint "no-floating-promise" Project_options.default
           (source "x.res" "let run = () => unknown()->ignore")) );
    ( "project required",
      error
        (lint "require-interface" Project_options.default
           (source "x.res" "let x = 1")) );
    ( "restriction policy required",
      error
        (lint "no-restricted-modules" Project_options.default
           (source "x.res" "let x = 1")) );
    ( "deprecated fallback",
      has "no-deprecated-api"
        (lint "no-deprecated-api" Project_options.default
           (source "x.res" "@deprecated let old = 1\nlet value = old")) );
    ( "nondeprecated attribute",
      not
        (has "no-deprecated-api"
           (lint "no-deprecated-api" Project_options.default
              (source "x.res" "@foo let old = 1\nlet value = old"))) );
    ( "license after same-line code",
      has "require-license-header"
        (lint "require-license-header" Project_options.default
           (source "x.res" "let x = 1 /* SPDX-License-Identifier: MIT */")) );
    ( "license empty source",
      has "require-license-header"
        (lint "require-license-header" Project_options.default
           (source "x.res" "")) );
    ( "license interface",
      not
        (has "require-license-header"
           (lint "require-license-header" Project_options.default
              (source ~kind:Interface "x.resi"
                 "// SPDX-License-Identifier: MIT\nlet x: int"))) );
    ( "suppression integration",
      not
        (has "no-console"
           (lint "no-console" Project_options.default
              (source "x.res"
                 "// rescript-lint-disable-next-line no-console -- intentional\n\
                  Console.log(1)"))) );
  ]

let discovery root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  Unix.mkdir (path "src/sub") 0o700;
  Unix.mkdir (path "src/node_modules") 0o700;
  write (path "src/Main.res") "let x = 1";
  write (path "src/readme.txt") "text";
  write (path "src/sub/Child.res") "let x = 1";
  write (path "src/node_modules/Ignored.res") "let x = 1";
  Unix.symlink (path "src/Main.res") (path "src/Link.res");
  let discover json =
    write (path "rescript.json") json;
    Project_files.discover ~root ~excluded:[]
  in
  let outcomes =
    [
      ( "missing project config",
        error (Project_files.discover ~root ~excluded:[]) );
      ("project malformed JSON", error (discover "{"));
      ("project object required", error (discover "[]"));
      ("invalid sources", error (discover "{\"sources\":false}"));
      ( "invalid source object",
        error (discover "{\"sources\":{\"dir\":\"src\",\"subdirs\":\"yes\"}}")
      );
      ("source root escape", error (discover "{\"sources\":\"../\"}"));
      ("missing directory", error (discover "{\"sources\":\"missing\"}"));
      ( "default recursive source",
        match discover "{}" with
        | Ok files -> List.length files = 2
        | _ -> false );
      ( "flat string source",
        discover "{\"sources\":\"src\"}" = Ok [ path "src/Main.res" ] );
      ( "flat object source",
        discover "{\"sources\":{\"dir\":\"src\"}}" = Ok [ path "src/Main.res" ]
      );
      ( "flat false source",
        discover "{\"sources\":{\"dir\":\"src\",\"subdirs\":false}}"
        = Ok [ path "src/Main.res" ] );
      ( "project root source",
        match discover "{\"sources\":{\"dir\":\".\",\"subdirs\":true}}" with
        | Ok files -> List.length files = 2
        | _ -> false );
    ]
  in
  write (path "rescript.json") "{}";
  write (path "src/sub/Main.res") "let x = 2";
  let duplicate = error (Project_files.load ~root ~excluded:[] ()) in
  Sys.remove (path "src/sub/Main.res");
  write (path "src/sub/Child.res") "let =";
  let invalid = error (Project_files.load ~root ~excluded:[] ()) in
  let options =
    {
      Project_options.default with
      root = Some root;
      excluded_paths = [ "src/sub" ];
    }
  in
  let main = source (path "src/Main.res") "let x = 1" in
  let missing_report = error (lint "no-unused-export" options main) in
  let entry =
    lint "no-unused-export" { options with entry_modules = [ "Main" ] } main
  in
  let iface =
    lint "require-interface" options
      (source ~kind:Interface (path "src/Main.resi") "let x: int")
  in
  outcomes
  @ [
      ("duplicate modules", duplicate);
      ("project parse error", invalid);
      ("unused requires report", missing_report);
      ("entry exemption", entry = Ok []);
      ("interface exempt", iface = Ok []);
      ( "missing project fails lint",
        error
          (lint "no-console" { options with root = Some (path "missing") } main)
      );
    ]

let reports root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  Unix.mkdir (path "lib") 0o700;
  Unix.mkdir (path "lib/bs") 0o700;
  Unix.mkdir (path "lib/bs/nested") 0o700;
  write (path "rescript.json") "{}";
  write (path "src/Main.res") "let x = 1\n";
  Unix.utimes (path "src/Main.res") 1000. 1000.;
  let report = path "report.json" in
  let src = source (path "src/Main.res") "let x = 1\n" in
  let run ?(overlay = src) target =
    match Project_files.load ~overlay ~root ~excluded:[] () with
    | Error _ -> Error "load"
    | Ok project -> Reanalyze_report.check ~project ~report ~source:target
  in
  let json filename line column =
    `List
      [
        `Assoc
          [
            ("name", `String "Warning Dead Value With Side Effects");
            ("file", `String filename);
            ("message", `String "unused x");
            ( "range",
              `List [ `Int line; `Int column; `Int line; `Int (column + 10) ] );
          ];
      ]
  in
  let save json =
    Yojson.Basic.to_file report json;
    Unix.utimes report 3000. 3000.
  in
  save (json "src/Main.res" 0 0);
  let missing = error (run src) in
  let artifact = path "lib/bs/nested/Main-Namespace.cmt" in
  write artifact "fixture";
  write (path "lib/bs/ignored.txt") "ignored";
  Unix.utimes artifact 500. 500.;
  let stale = error (run src) in
  Unix.utimes artifact 2000. 2000.;
  let fresh = match run src with Ok [ _ ] -> true | _ -> false in
  let unsaved = error (run ~overlay:{ src with text = "let x = 2\n" } src) in
  let outside = error (run { src with filename = path "Outside.res" }) in
  save (json "src/Main.res" 0 5);
  let unlocated = run src = Ok [] in
  save (json "src/Other.res" 0 0);
  let unrelated = run src = Ok [] in
  write report "{";
  let malformed = error (run src) in
  Sys.remove report;
  let absent = error (run src) in
  [
    ("missing compiler artifact", missing);
    ("stale artifact", stale);
    ("fresh namespaced nested artifact", fresh);
    ("unsaved overlay", unsaved);
    ("source outside project", outside);
    ("unlocated analyzer finding", unlocated);
    ("unrelated analyzer finding", unrelated);
    ("malformed report", malformed);
    ("missing report", absent);
    ( "negative report location",
      error (Reanalyze_report.decode (json "Main.res" (-1) 0)) );
  ]

let () =
  let checks = local @ temporary discovery @ temporary reports in
  let failed =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
