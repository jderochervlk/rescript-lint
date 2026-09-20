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

let () =
  let filename = Filename.temp_file "rescript-lint-watch" ".res" in
  let missing = filename ^ ".missing" in
  let checks =
    [
      ("reports one change across two polls", polling_check filename);
      ("detects a file appearing", unavailable_check missing);
      ("absorbs changes made by fix mode", refresh_check filename);
    ]
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
