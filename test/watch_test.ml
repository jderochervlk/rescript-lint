open Rescript_linter

let write filename text =
  Out_channel.with_open_text filename (fun channel ->
      output_string channel text)

let polling_check filename =
  write filename "let value = 1\n";
  let initial = Watch.observe [ filename ] in
  let polls = ref 0 in
  let changes = ref 0 in
  let sleep () =
    incr polls;
    if !polls = 1 then write filename "let changed = 2\n"
  in
  let dependencies = Watch.{ observe; sleep } in
  Watch.loop ~dependencies
    ~continue:(fun () -> !polls < 2)
    ~on_change:(fun () -> incr changes)
    ~refresh_after_change:false ~files:[ filename ] ~initial;
  !changes = 1

let unavailable_check filename =
  let initial = Watch.observe [ filename ] in
  let polls = ref 0 in
  let changes = ref 0 in
  let sleep () =
    incr polls;
    if !polls = 1 then write filename "let created = 1\n"
  in
  let dependencies = Watch.{ observe; sleep } in
  Watch.loop ~dependencies
    ~continue:(fun () -> !polls < 1)
    ~on_change:(fun () -> incr changes)
    ~refresh_after_change:false ~files:[ filename ] ~initial;
  !changes = 1

let refresh_check filename =
  write filename "let value = 1\n";
  let initial = Watch.observe [ filename ] in
  let polls = ref 0 in
  let changes = ref 0 in
  let sleep () =
    incr polls;
    if !polls = 1 then write filename "input->consume\ndone()\n"
  in
  let on_change () =
    incr changes;
    write filename "input->consume\n\ndone()\n"
  in
  let dependencies = Watch.{ observe; sleep } in
  Watch.loop ~dependencies
    ~continue:(fun () -> !polls < 2)
    ~on_change ~refresh_after_change:true ~files:[ filename ] ~initial;
  !changes = 1

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  let root = Filename.temp_file "rescript-lint-watch-project" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let project_checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") "{}";
  write (path "src/Main.res") "let value = 1";
  let options = { Project_options.default with root = Some root } in
  let rules = Rule_config.with_options options Rule_config.default in
  let snapshot ?(files = []) () =
    Watch.observe_inputs ~rules ~files ~configuration:[]
  in
  let initial = snapshot () in
  let stable = initial = snapshot () in
  write (path "src/New.res") "let value = 2";
  let added = snapshot () <> initial in
  let with_new = snapshot ~files:[ path "src/Main.res" ] () in
  write (path "src/New.res") "let changed = 3";
  let provider = snapshot ~files:[ path "src/Main.res" ] () <> with_new in
  let before_delete = snapshot () in
  Sys.remove (path "src/New.res");
  let deleted = snapshot () <> before_delete in
  write (path "rescript.json") "{";
  let failed = snapshot () in
  let error_stable = failed = snapshot () in
  write (path "rescript.json") "{}";
  let recovered = snapshot () <> failed in
  [
    ("project snapshot stable", stable);
    ("discovers added file", added);
    ("explicit consumer watches providers", provider);
    ("detects removed file", deleted);
    ("discovery failure is stable", error_stable);
    ("discovery recovery detected", recovered);
  ]

let selection_checks root =
  let path name = Filename.concat root name in
  write (path "lint.json") "{}";
  let snapshot () =
    Watch.observe_inputs ~rules:Rule_config.default ~files:[]
      ~configuration:[ path "lint.json" ]
  in
  let before = snapshot () in
  write (path "lint.json") "{\"rules\":{}}";
  let config_changed = before <> snapshot () in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") "{}";
  let rules =
    Rule_config.with_options
      {
        Project_options.default with
        root = Some root;
        excluded_paths = [ "src/Skip.res" ];
      }
      Rule_config.default
  in
  let selected () = Watch.observe_inputs ~rules ~files:[] ~configuration:[] in
  let initial = selected () in
  write (path "src/Skip.res") "let value = 1";
  let excluded = initial = selected () in
  let polls = ref 0 in
  let changes = ref 0 in
  let wait () =
    incr polls;
    if !polls = 1 then write (path "src/Added.res") "let value = 2"
  in
  Watch.loop_dynamic
    ~dependencies:{ snapshot = selected; wait }
    ~continue:(fun () -> !polls < 2)
    ~on_change:(fun () -> incr changes)
    ~refresh_after_change:true ~initial;
  [
    ("configuration path observed", config_changed);
    ("excluded new file ignored", excluded);
    ("dynamic loop tracks additions without duplicate runs", !changes = 1);
  ]

let command_checks root =
  let config = Filename.concat root "lint.json" in
  write config "{}";
  let arguments = [ "--watch"; "--config"; config; "Main.res" ] in
  let initial = Watch.command_snapshot arguments in
  write config "{";
  let invalid = Watch.command_snapshot arguments in
  let stable = invalid = Watch.command_snapshot arguments in
  write config "{}";
  let recovered = Watch.command_snapshot arguments <> invalid in
  let literal = [ "--watch"; "--"; "--config"; config ] in
  let before = Watch.command_snapshot literal in
  write config "{\"rules\":{}}";
  let literal_observed = before <> Watch.command_snapshot literal in
  let valued = [ "--watch"; "--project"; root; "--format"; "human" ] in
  write (Filename.concat root "rescript.json") "{\"sources\":[]}";
  [
    ("config syntax failure detected", initial <> invalid);
    ("command failure stable", stable);
    ("command config recovery detected", recovered);
    ("delimiter paths remain observed as inputs", literal_observed);
    ( "non-watch command has explicit snapshot state",
      Watch.command_snapshot [ "--help" ] <> Watch.observe [] );
    ( "valued options are not config paths",
      Watch.command_snapshot valued
      = Watch.observe [ Filename.concat root "rescript.json" ] );
  ]

let dependency_checks root =
  let path name = Filename.concat root name in
  write (path "rescript.json") "{\"sources\":[]}";
  Unix.mkdir (path "pkg") 0o700;
  Unix.mkdir (path "pkg/src") 0o700;
  write (path "pkg/rescript.json") "{\"name\":\"pkg\",\"sources\":[\"src\"]}";
  write (path "pkg/src/Api.resi") "@throws let call: unit => unit";
  write (path "report.json") "[]";
  let options =
    {
      Project_options.default with
      root = Some root;
      throws_dependencies = [ path "pkg" ];
      reanalyze_report = Some (path "report.json");
    }
  in
  let rules = Rule_config.with_options options Rule_config.default in
  let snapshot rules =
    Watch.observe_inputs ~rules ~files:[] ~configuration:[]
  in
  let before = snapshot rules in
  write (path "pkg/src/Api.resi") "let call: unit => unit";
  let changed = snapshot rules <> before in
  let before_report = snapshot rules in
  write (path "report.json") "[{}]";
  let report = snapshot rules <> before_report in
  Sys.remove (path "pkg/rescript.json");
  let failure = snapshot rules in
  let disabled =
    match Rule_config.set rules ~id:"no-unhandled-throws" ~enabled:false with
    | Error _ -> false
    | Ok rules ->
        snapshot rules
        = Watch.observe [ path "report.json"; path "rescript.json" ]
  in
  write (path "pkg/rescript.json") "{\"name\":\"pkg\",\"sources\":[\"src\"]}";
  [
    ("dependency declarations watched", changed);
    ("reanalyze report watched", report);
    ("disabled throws skips dependency discovery", disabled);
    ("dependency discovery recovery detected", snapshot rules <> failure);
  ]

let () =
  let filename = Filename.temp_file "rescript-lint-watch" ".res" in
  let missing = filename ^ ".missing" in
  let checks =
    [
      ("reports one change across two polls", polling_check filename);
      ("detects a file appearing", unavailable_check missing);
      ("absorbs changes made by fix mode", refresh_check filename);
    ]
    @ temporary project_checks @ temporary selection_checks
    @ temporary command_checks
    @ temporary dependency_checks
  in
  Sys.remove filename;
  Sys.remove missing;
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
