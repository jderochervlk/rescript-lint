open Rescript_linter

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
  let root = Filename.temp_file "lint-index-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") "{}";
  let source =
    Source.
      {
        filename = path "src/Main.res";
        text = "let value = Provider.old";
        kind = Implementation;
      }
  in
  write source.filename source.text;
  write (path "src/Provider.resi") "@deprecated(\"Use modern\") let old: int";
  let calls = ref 0 in
  let parse source =
    incr calls;
    Parser.parse source
  in
  let cache = ref (Project_index.create ~parse) in
  let load_project ~config ~source =
    let next, result = Project_context.load_cached !cache ~config ~source in
    cache := next;
    result
  in
  let options = { Project_options.default with root = Some root } in
  match
    Rule_config.set
      (Rule_config.with_options options Rule_config.default)
      ~id:"no-deprecated-api" ~enabled:true
  with
  | Error _ -> [ ("configuration valid", false) ]
  | Ok config ->
      let lint source =
        Linter.lint_source_with_loader ~load_project config source
      in
      let first = lint source in
      let uncached = Linter.lint_source_with_rules config source in
      let first_calls = !calls in
      let again = lint source in
      let reused = !calls = first_calls + 1 in
      write (path "src/Provider.resi") "let old: int";
      let updated = lint source in
      write (path "src/Provider.resi") "let =";
      let invalid = lint source in
      write (path "src/Provider.resi") "let old: int";
      let recovered = lint source in
      let _, standalone =
        Project_context.load_cached !cache ~config:Rule_config.default ~source
      in
      [
        ("cached and uncached diagnostics match", first = uncached);
        ( "cached lint retains findings",
          first = again && Result.is_ok first && first <> Ok [] );
        ("unchanged provider parse reused", reused);
        ("changed interface recomputes diagnostics", updated = Ok []);
        ("invalid provider never returns stale success", Result.is_error invalid);
        ("fixed provider recovers", recovered = Ok []);
        ("no project remains standalone", standalone = Ok None);
      ]

let () =
  let failed =
    temporary checks
    |> List.filter_map (fun (name, passed) ->
        if passed then None else Some name)
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
