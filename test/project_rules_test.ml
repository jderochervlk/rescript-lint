open Rescript_linter

let source filename text = Source.{ filename; text; kind = Implementation }
let is_error = function Error _ -> true | Ok _ -> false

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let enabled id options =
  Rule_config.set
    (Rule_config.with_options options Rule_config.default)
    ~id ~enabled:true

let check id options source predicate =
  match enabled id options with
  | Error _ -> false
  | Ok config -> (
      match Linter.lint_source_with_rules config source with
      | Error _ -> false
      | Ok findings ->
          predicate
            (List.filter
               (fun (finding : Diagnostic.t) -> finding.rule = id)
               findings))

let found = function _ :: _ -> true | [] -> false
let clean = function [] -> true | _ -> false

let local_checks =
  [
    ( "deprecated local module",
      check "no-deprecated-api" Project_options.default
        (source "api.res"
           "module Api = {@deprecated(\"Use modern\") let old = x => x}\n\
            let value = Api.old(1)")
        found );
    ( "deprecated local alias",
      check "no-deprecated-api" Project_options.default
        (source "api.res"
           "@deprecated(\"Use modern\") let old = x => x\n\
            let alias = old\n\
            let value = alias(1)")
        found );
    ( "deprecated shadow",
      check "no-deprecated-api" Project_options.default
        (source "api.res"
           "module Api = {@deprecated(\"Use modern\") let old = x => x}\n\
            let f = old => old(1)")
        clean );
    ( "license missing",
      check "require-license-header" Project_options.default
        (source "license.res" "let x = 1")
        found );
    ( "license exact",
      check "require-license-header" Project_options.default
        (source "license.res" "// SPDX-License-Identifier: MIT\nlet x = 1")
        clean );
    ( "license mismatch",
      check "require-license-header" Project_options.default
        (source "license.res"
           "// SPDX-License-Identifier: Apache-2.0\nlet x = 1")
        found );
    ( "license block",
      check "require-license-header" Project_options.default
        (source "license.res"
           "/*\n * SPDX-License-Identifier: MIT\n */\nlet x = 1")
        clean );
    ( "license in string",
      check "require-license-header" Project_options.default
        (source "license.res" "let x = \"SPDX-License-Identifier: MIT\"")
        found );
    ( "license after code",
      check "require-license-header" Project_options.default
        (source "license.res" "let x = 1\n// SPDX-License-Identifier: MIT")
        found );
    ("report non-array", is_error (Reanalyze_report.decode (`Assoc [])));
    ( "report invalid member",
      is_error (Reanalyze_report.decode (`List [ `Null ])) );
    ( "report missing name",
      is_error (Reanalyze_report.decode (`List [ `Assoc [] ])) );
    ( "report other issue",
      Reanalyze_report.decode
        (`List [ `Assoc [ ("name", `String "Warning Dead Type") ] ])
      = Ok [] );
    ( "report malformed value",
      is_error
        (Reanalyze_report.decode
           (`List [ `Assoc [ ("name", `String "Warning Dead Value") ] ])) );
  ]

let setup root =
  Unix.mkdir (Filename.concat root "src") 0o700;
  write
    (Filename.concat root "rescript.json")
    "{\"sources\":[{\"dir\":\"src\",\"subdirs\":true}]}";
  write
    (Filename.concat root "src/Api.res")
    "let old = x => x\nlet hidden = 1\n";
  write
    (Filename.concat root "src/Api.resi")
    "@deprecated(\"Use modern\")\nlet old: int => int\n";
  write (Filename.concat root "src/Main.res") "let value = Api.old(1)\n";
  Unix.mkdir (Filename.concat root "src/generated") 0o700;
  write (Filename.concat root "src/generated/Generated.res") "let value = 0\n"

let rec remove directory =
  Sys.readdir directory
  |> Array.iter (fun name ->
      let path = Filename.concat directory name in
      if (Unix.lstat path).st_kind = Unix.S_DIR then remove path
      else Sys.remove path);
  Unix.rmdir directory

let with_project run =
  let root = Filename.temp_file "rescript-project-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect
    ~finally:(fun () -> remove root)
    (fun () ->
      setup root;
      run root)

let project_checks root =
  let options =
    {
      Project_options.default with
      root = Some root;
      excluded_paths = [ "src/generated" ];
    }
  in
  let main = Filename.concat root "src/Main.res" in
  let api = Filename.concat root "src/Api.res" in
  let source = source main "let value = Api.old(1)\n" in
  let loaded = Project_files.load ~root ~excluded:options.excluded_paths () in
  [
    ( "discover deterministic",
      match
        Inputs.files (Rule_config.with_options options Rule_config.default) []
      with
      | Ok files -> files = [ api; api ^ "i"; main ]
      | _ -> false );
    ( "project loaded",
      match loaded with
      | Ok project -> List.length project.units = 3
      | _ -> false );
    ("interface precedence", check "no-deprecated-api" options source found);
    ( "restricted canonical",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        source found );
    ( "restricted module alias",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        { source with text = "module A = Api\nlet value = A.old(1)" }
        found );
    ( "unrestricted",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Database" ] }
        source clean );
    ( "require existing interface",
      check "require-interface" options
        { source with filename = api; text = "let old = x => x" }
        clean );
    ("require missing interface", check "require-interface" options source found);
    ( "overlay parsed",
      match
        Project_files.load
          ~overlay:{ source with text = "let =" }
          ~root ~excluded:options.excluded_paths ()
      with
      | Error _ -> true
      | _ -> false );
    ( "export interface filtering",
      match loaded with
      | Ok project -> (
          match
            List.find_opt
              (fun unit -> unit.Project_files.source.filename = api)
              project.units
          with
          | Some unit ->
              List.map
                (fun declaration -> declaration.Project_exports.path)
                (Project_exports.public project unit)
              = [ [ "old" ] ]
          | _ -> false)
      | _ -> false );
    ( "report needs metadata",
      match loaded with
      | Ok project ->
          is_error
            (Reanalyze_report.check ~project
               ~report:(Filename.concat root "report.json")
               ~source)
      | _ -> false );
  ]

let report_checks root =
  let options =
    {
      Project_options.default with
      root = Some root;
      excluded_paths = [ "src/generated" ];
    }
  in
  let report = Filename.concat root "report.json" in
  let api = Filename.concat root "src/Api.res" in
  Unix.mkdir (Filename.concat root "lib") 0o700;
  Unix.mkdir (Filename.concat root "lib/bs") 0o700;
  List.iter
    (fun filename ->
      write (Filename.concat root ("lib/bs/" ^ filename)) "fixture artifact";
      Unix.utimes (Filename.concat root ("lib/bs/" ^ filename)) 2000. 2000.)
    [ "Api.cmt"; "Api.cmti"; "Main.cmt" ];
  List.iter
    (fun path -> Unix.utimes (Filename.concat root path) 1000. 1000.)
    [ "src/Api.res"; "src/Api.resi"; "src/Main.res" ];
  Yojson.Basic.to_file report
    (`List
       [
         `Assoc
           [
             ("name", `String "Warning Dead Value");
             ("file", `String api);
             ("range", `List [ `Int 0; `Int 0; `Int 0; `Int 20 ]);
             ("message", `String "old is never used");
           ];
       ]);
  Unix.utimes report 3000. 3000.;
  let loaded = Project_files.load ~root ~excluded:options.excluded_paths () in
  let result =
    match (loaded, Source.read api) with
    | Ok project, Ok source -> Reanalyze_report.check ~project ~report ~source
    | _ -> Error "fixture"
  in
  Unix.utimes report 1500. 1500.;
  let stale =
    match (loaded, Source.read api) with
    | Ok project, Ok source -> Reanalyze_report.check ~project ~report ~source
    | _ -> Ok []
  in
  [
    ("fresh analyzer report", match result with Ok [ _ ] -> true | _ -> false);
    ("stale analyzer report rejected", is_error stale);
  ]

let () =
  let checks =
    local_checks @ with_project project_checks @ with_project report_checks
  in
  let failed =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
