open Rescript_linter

let write filename text =
  Out_channel.with_open_text filename (fun channel ->
      output_string channel text)

let rec remove path =
  if Sys.is_directory path then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  let root = Filename.temp_file "empty-project-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let field key response =
  match response.Cli_runner.stdout with
  | [ text ] -> Yojson.Basic.Util.member key (Yojson.Basic.from_string text)
  | _ -> `Null

let run arguments =
  Cli_runner.run ~lint:(fun _ _ -> Ok []) ~fix:(fun _ _ -> Ok []) arguments

let workspace_checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "child") 0o700;
  Unix.mkdir (path "child/src") 0o700;
  write (path "rescript.json") {|{"sources":[],"dependencies":["child"]}|};
  write (path "child/rescript.json") {|{"sources":["src"]}|};
  write (path "child/src/View.res") "let value = 1";
  let arguments = [ "--project"; root ] in
  let human = run arguments in
  let warning =
    (Report.empty_project ~root).warnings
    |> List.map (fun text -> "Warning: " ^ text)
  in
  let modes = [ []; [ "--fix" ]; [ "--watch" ]; [ "--watch"; "--fix" ] ] in
  let empty_modes =
    List.for_all
      (fun mode ->
        let response = run ([ "--format"; "json" ] @ mode @ arguments) in
        response.outcome = Clean && response.stderr = []
        && field "checkedFileCount" response = `Int 0
        && field "errors" response = `List []
        && field "warnings" response
           = `List
               (List.map
                  (fun text -> `String text)
                  (Report.empty_project ~root).warnings))
      modes
  in
  let child = run [ "--format"; "json"; "--project"; path "child" ] in
  let explicit =
    run ([ "--format"; "json" ] @ arguments @ [ path "child/src/View.res" ])
  in
  write (path "child/lint.json") {|{"root":".","exclude":["src"]}|};
  let excluded =
    run [ "--format"; "json"; "--config"; path "child/lint.json" ]
  in
  [
    ( "empty human warning without failure",
      human.outcome = Clean && human.stdout = [] && human.stderr = warning );
    ("empty lint fix and watch structured reports", empty_modes);
    ( "explicit child selection checks its sources",
      field "checkedFileCount" child = `Int 1
      && field "warnings" child = `List [] );
    ( "explicit files bypass empty project discovery",
      field "checkedFileCount" explicit = `Int 1
      && field "warnings" explicit = `List [] );
    ( "all excluded sources warn",
      field "checkedFileCount" excluded = `Int 0
      && field "warnings" excluded <> `List []
      && excluded.outcome = Clean );
  ]

let watch_checks root =
  let config = Filename.concat root "rescript.json" in
  write config {|{"sources":[]}|};
  let arguments = [ "--format"; "json"; "--watch"; "--project"; root ] in
  let initial = Watch.command_snapshot arguments in
  let empty = run arguments in
  write (Filename.concat root "Main.res") "let value = 1";
  write config {|{"sources":["."]}|};
  let populated = run arguments in
  [
    ( "watch recovers from empty selection",
      Watch.command_snapshot arguments <> initial
      && field "checkedFileCount" empty = `Int 0
      && field "checkedFileCount" populated = `Int 1
      && field "warnings" populated = `List [] );
  ]

let () =
  let failures =
    temporary workspace_checks @ temporary watch_checks
    |> List.filter_map (fun (name, passed) ->
        if passed then None else Some name)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
