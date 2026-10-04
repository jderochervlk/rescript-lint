open Rescript_linter

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Unix.chmod path 0o700;
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  let root = Filename.temp_file "source-root-policy-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let checks root =
  let nested = Filename.concat root "nested" in
  let sibling = root ^ "-sibling" in
  let file = Filename.concat root "file.res" in
  let link = Filename.concat root "link" in
  let unreadable = Filename.concat root "unreadable" in
  Unix.mkdir nested 0o700;
  Unix.mkdir unreadable 0o700;
  write file "let value = 1";
  Unix.symlink nested link;
  let loaded = Source_root_policy.load [ root ] in
  let relative =
    let cwd = Sys.getcwd () in
    Fun.protect
      ~finally:(fun () -> Sys.chdir cwd)
      (fun () ->
        Sys.chdir (Filename.dirname root);
        Source_root_policy.load [ Filename.basename root ])
  in
  let containment =
    match loaded with
    | Error _ -> false
    | Ok [ configured ] ->
        Source_root_policy.contains configured ~filename:root
        && Source_root_policy.contains configured ~filename:file
        && (not (Source_root_policy.contains configured ~filename:sibling))
        && Source_root_policy.contains configured
             ~filename:(Filename.concat root "missing/deep/file.res")
        && Source_root_policy.matching [ configured ] ~filename:file
           = Some configured
        && Source_root_policy.matching [ configured ] ~filename:sibling = None
    | Ok _ -> false
  in
  let symlink_duplicate =
    Result.is_error (Source_root_policy.load [ nested; link ])
  in
  let file_rejected = Result.is_error (Source_root_policy.load [ file ]) in
  let missing_rejected =
    Result.is_error (Source_root_policy.load [ Filename.concat root "missing" ])
  in
  Unix.chmod unreadable 0o000;
  let unreadable_result = Source_root_policy.load [ unreadable ] in
  Unix.chmod unreadable 0o700;
  [
    ("loads absolute directory", Result.is_ok loaded);
    ("loads relative directory", Result.is_ok relative);
    ("directory boundary containment", containment);
    ( "filesystem root containment",
      Source_root_policy.contains
        { configured = Filename.dir_sep; canonical = Filename.dir_sep }
        ~filename:file );
    ("canonical duplicate rejected", symlink_duplicate);
    ("regular file rejected", file_rejected);
    ("missing directory rejected", missing_rejected);
    ("unreadable directory rejected", Result.is_error unreadable_result);
    ("empty roots encode", Source_root_policy.encode [] = `List []);
  ]

let () =
  let failures =
    temporary checks
    |> List.filter_map (fun (name, passed) ->
        if passed then None else Some name)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
