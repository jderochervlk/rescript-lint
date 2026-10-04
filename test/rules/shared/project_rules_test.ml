open Rescript_linter
open Project_rules_test_support

let is_error = function Error _ -> true | Ok _ -> false

let local_checks =
  [
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
        Input_files.resolve
          (Rule_config.with_options options Rule_config.default)
          []
      with
      | Ok files -> files = [ api; api ^ "i"; main ]
      | _ -> false );
    ( "project loaded",
      match loaded with
      | Ok project -> List.length project.units = 3
      | _ -> false );
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
