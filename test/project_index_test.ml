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

let setup root =
  Unix.mkdir (Filename.concat root "src") 0o700;
  write
    (Filename.concat root "rescript.json")
    "{\"sources\":[{\"dir\":\"src\",\"subdirs\":true}]}";
  write (Filename.concat root "src/Api.res") "let read = () => 1";
  write (Filename.concat root "src/Main.res") "let value = 1"

let temporary run =
  let root = Filename.temp_file "project-index-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect
    ~finally:(fun () -> remove root)
    (fun () ->
      setup root;
      run root)

let load ?overlay ?(excluded = []) root cache =
  Project_index.load ?overlay ~root ~excluded cache

let stats outcome parsed reused overlays =
  outcome.Project_index.stats = { parsed; reused; overlays }

let success outcome = Result.is_ok outcome.Project_index.project
let error outcome = Result.is_error outcome.Project_index.project

let unit_named name kind outcome =
  Option.bind (Result.to_option outcome.Project_index.project) (fun project ->
      List.find_opt
        (fun unit -> unit.Project_files.name = name && unit.source.kind = kind)
        project.Project_files.units)

let binding_literal expected binding =
  match binding.Parsetree.pvb_expr.pexp_desc with
  | Pexp_constant (Pconst_integer (actual, None)) -> actual = expected
  | _ -> false

let tree_literal name expected outcome =
  match unit_named name Source.Implementation outcome with
  | Some
      {
        tree =
          Parser.Implementation
            [ { pstr_desc = Pstr_value (_, [ binding ]); _ } ];
        _;
      } ->
      binding_literal expected binding
  | _ -> false

let basic root =
  let calls = ref 0 in
  let parse source =
    incr calls;
    Parser.parse source
  in
  let empty = Project_index.create ~parse in
  let first = load root empty in
  let repeated = load root first.cache in
  let canonical = load (Filename.concat root "src/..") repeated.cache in
  let independent = load root empty in
  [
    ("initial project parses every file", success first && stats first 2 0 0);
    ( "unchanged project reuses every parse",
      success repeated && stats repeated 0 2 0 );
    ( "canonical root aliases reuse same cache",
      success canonical && stats canonical 0 2 0 );
    ("original empty cache remains immutable", stats independent 2 0 0);
    ("parser injection observes real reuse", !calls = 4);
  ]

let changed_contents root =
  let filename = Filename.concat root "src/Main.res" in
  Unix.utimes filename 1700000000.0 1700000000.0;
  let first = load root Project_index.empty in
  let before = Unix.stat filename in
  write filename "let value = 2";
  Unix.utimes filename before.st_atime before.st_mtime;
  let changed = load root first.cache in
  Unix.utimes filename before.st_atime (before.st_mtime +. 10.);
  let observed_modified = (Unix.stat filename).st_mtime in
  let timestamp = load root changed.cache in
  write filename "let value = 1";
  let old_snapshot = load root first.cache in
  [
    ( "same timestamp and length still detect content change",
      success changed && stats changed 1 1 0 && tree_literal "Main" "2" changed
    );
    ( "timestamp-only change reuses parse",
      success timestamp && stats timestamp 0 2 0 );
    ( "metadata timestamp stays fresh on parse reuse",
      Option.fold ~none:false
        ~some:(fun unit -> unit.Project_files.modified = observed_modified)
        (unit_named "Main" Source.Implementation timestamp) );
    ( "prior successful cache remains immutable",
      stats old_snapshot 0 2 0 && tree_literal "Main" "1" old_snapshot );
  ]

let added_and_removed root =
  let first = load root Project_index.empty in
  let filename = Filename.concat root "src/Extra.res" in
  write filename "let extra = true";
  let added = load root first.cache in
  Sys.remove filename;
  let removed = load root added.cache in
  write filename "let extra = true";
  let restored = load root removed.cache in
  [
    ( "new files are parsed",
      success added && stats added 1 2 0
      && Option.is_some (unit_named "Extra" Source.Implementation added) );
    ( "deleted files disappear",
      success removed && stats removed 0 2 0
      && Option.is_none (unit_named "Extra" Source.Implementation removed) );
    ("deleted entries are pruned", stats restored 1 2 0);
  ]

let interfaces root =
  let first = load root Project_index.empty in
  let filename = Filename.concat root "src/Api.resi" in
  write filename "let read: unit => int";
  let added = load root first.cache in
  let has_interface =
    Result.fold
      ~ok:(fun project ->
        Option.is_some (Project_files.signature project "Api"))
      ~error:(fun _ -> false)
      added.project
  in
  write filename "let read: unit => string";
  let changed = load root added.cache in
  Sys.remove filename;
  let removed = load root changed.cache in
  [
    ( "new interface changes public contract availability",
      success added && has_interface && stats added 1 2 0 );
    ( "changed interface is parsed independently",
      success changed && stats changed 1 2 0 );
    ( "removed interface no longer masks implementation",
      success removed && stats removed 0 2 0
      && Option.is_none (unit_named "Api" Source.Interface removed) );
  ]

let exclusions root =
  let initial =
    load ~excluded:[ "src/unused"; "src/generated" ] root Project_index.empty
  in
  let reordered =
    load
      ~excluded:[ "src/generated"; "src/unused"; "src/unused" ]
      root initial.cache
  in
  let excluded = load ~excluded:[ "src/Api.res" ] root reordered.cache in
  let restored = load root excluded.cache in
  [
    ("equivalent exclusions preserve cache selection", stats reordered 0 2 0);
    ( "changed exclusions isolate selected snapshot",
      success excluded && stats excluded 1 0 0
      && Option.is_none (unit_named "Api" Source.Implementation excluded) );
    ("restored exclusion selection reparses its snapshot", stats restored 2 0 0);
  ]

let config_sources root =
  Unix.mkdir (Filename.concat root "src/nested") 0o700;
  write (Filename.concat root "src/nested/Nested.res") "let nested = true";
  let filename = Filename.concat root "rescript.json" in
  Unix.utimes filename 1700000000.0 1700000000.0;
  let first = load root Project_index.empty in
  let before = Unix.stat filename in
  write filename "{\"sources\":\"src\"}";
  Unix.utimes filename before.st_atime before.st_mtime;
  let flat = load root first.cache in
  write filename "{\"sources\":[{\"dir\":\"src\",\"subdirs\":true}]}";
  let recursive = load root flat.cache in
  [
    ( "config content changes rediscover without timestamp reliance",
      success flat && stats flat 0 2 0
      && Option.is_none (unit_named "Nested" Source.Implementation flat) );
    ( "config-unselected cache entries were pruned",
      success recursive && stats recursive 1 2 0 );
  ]

let changed_root root =
  let first = load root Project_index.empty in
  temporary (fun other ->
      let changed = load other first.cache in
      let restored = load root changed.cache in
      [
        ( "different root cannot reuse same module names",
          success changed && stats changed 2 0 0 );
        ("cache only retains current root", stats restored 2 0 0);
      ])

let overlay root value =
  Source.
    {
      filename = Filename.concat root "src/Main.res";
      kind = Implementation;
      text = value;
    }

let overlays root =
  let first = load root Project_index.empty in
  let same = load ~overlay:(overlay root "let value = 1") root first.cache in
  let changed = load ~overlay:(overlay root "let value = 3") root same.cache in
  let repeated =
    load ~overlay:(overlay root "let value = 3") root changed.cache
  in
  let closed = load root repeated.cache in
  [
    ("identical overlay can reuse verified disk parse", stats same 0 2 1);
    ( "overlay contents are authoritative",
      success changed && stats changed 1 1 1 && tree_literal "Main" "3" changed
    );
    ("changed overlay is not cached as disk", stats repeated 1 1 1);
    ( "closing overlay restores disk without poisoning",
      success closed && stats closed 0 2 0 && tree_literal "Main" "1" closed );
  ]

let overlay_disk_changes root =
  let first = load root Project_index.empty in
  write (Filename.concat root "src/Main.res") "let value = 2";
  let opened = load ~overlay:(overlay root "let value = 3") root first.cache in
  let closed = load root opened.cache in
  [
    ( "overlay supersedes concurrent disk changes",
      tree_literal "Main" "3" opened );
    ( "closing overlay detects changed disk content",
      stats closed 1 1 0 && tree_literal "Main" "2" closed );
  ]

let overlay_identity root =
  write (Filename.concat root "src/Main.res") "type t = int";
  let first = load root Project_index.empty in
  let different_kind =
    { (overlay root "type t = int") with kind = Source.Interface }
  in
  let changed_kind = load ~overlay:different_kind root first.cache in
  let alias =
    {
      (overlay root "type t = int") with
      filename = Filename.concat root "src/../src/Main.res";
    }
  in
  let changed_path = load ~overlay:alias root first.cache in
  let location_matches =
    match unit_named "Main" Source.Implementation changed_path with
    | Some { tree = Parser.Implementation (first :: _); _ } ->
        first.pstr_loc.loc_start.pos_fname = alias.filename
    | _ -> false
  in
  [
    ( "source kind participates in cache identity",
      stats changed_kind 1 1 1
      && Option.is_some (unit_named "Main" Source.Interface changed_kind) );
    ( "source filename participates in AST location identity",
      stats changed_path 1 1 1 && location_matches );
  ]

let overlay_errors root =
  let first = load root Project_index.empty in
  let invalid = load ~overlay:(overlay root "let =") root first.cache in
  let closed = load root invalid.cache in
  let outside =
    {
      (overlay root "let =") with
      filename = Filename.concat root "unselected.res";
    }
  in
  let ignored = load ~overlay:outside root closed.cache in
  [
    ( "invalid overlay cannot return stale project success",
      error invalid && stats invalid 1 1 1 );
    ( "invalid overlay leaves independent disk cache intact",
      success closed && stats closed 0 2 0 );
    ( "unselected overlay preserves existing discovery contract",
      success ignored && stats ignored 0 2 0 );
  ]

let disk_errors root =
  let first = load root Project_index.empty in
  write (Filename.concat root "src/Main.res") "let =";
  let invalid = load root first.cache in
  write (Filename.concat root "src/Main.res") "let value = 1";
  let repaired = load root invalid.cache in
  write (Filename.concat root "rescript.json") "{";
  let config_error = load root repaired.cache in
  write (Filename.concat root "rescript.json") "{\"sources\":\"src\"}";
  let config_repaired = load root config_error.cache in
  [
    ( "disk parse error cannot return cached success",
      error invalid && stats invalid 1 1 0 );
    ( "disk parse error clears cached entries",
      success repaired && stats repaired 2 0 0 );
    ( "malformed configuration is reread",
      error config_error && stats config_error 0 0 0 );
    ( "configuration error clears cache",
      success config_repaired && stats config_repaired 2 0 0 );
  ]

let duplicate_modules root =
  let first = load root Project_index.empty in
  Unix.mkdir (Filename.concat root "src/nested") 0o700;
  let duplicate = Filename.concat root "src/nested/Main.res" in
  write duplicate "let other = true";
  let invalid = load root first.cache in
  Sys.remove duplicate;
  let repaired = load root invalid.cache in
  [
    ("new duplicate modules never reuse old project success", error invalid);
    ( "duplicate-module failure clears cached entries",
      success repaired && stats repaired 2 0 0 );
  ]

let file_race ~delete_current root =
  let trigger = ref false in
  let first_name = if delete_current then "Main.res" else "Api.res" in
  let victim = Filename.concat root "src/Main.res" in
  let parse source =
    if !trigger && Filename.basename source.Source.filename = first_name then
      Sys.remove victim;
    Parser.parse source
  in
  let first = load root (Project_index.create ~parse) in
  trigger := true;
  write (Filename.concat root ("src/" ^ first_name)) "let changed = true";
  let invalid = load root first.cache in
  trigger := false;
  write victim "let value = 1";
  let repaired = load root invalid.cache in
  [
    ( (if delete_current then "stat failure" else "read failure")
      ^ " cannot return cached success",
      error invalid );
    ( (if delete_current then "stat failure" else "read failure")
      ^ " clears cache",
      success repaired && stats repaired 2 0 0 );
  ]

let missing_config root =
  let first = load root Project_index.empty in
  Sys.remove (Filename.concat root "rescript.json");
  let invalid = load root first.cache in
  [
    ( "missing config returns read error without cached success",
      error invalid && stats invalid 0 0 0 );
  ]

let checks =
  List.concat_map temporary
    [
      basic;
      changed_contents;
      added_and_removed;
      interfaces;
      exclusions;
      config_sources;
      changed_root;
      overlays;
      overlay_disk_changes;
      overlay_identity;
      overlay_errors;
      disk_errors;
      duplicate_modules;
      file_race ~delete_current:false;
      file_race ~delete_current:true;
      missing_config;
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  match failures with
  | [] -> Printf.printf "project index: %d checks passed\n" (List.length checks)
  | _ ->
      List.iter prerr_endline failures;
      exit 1
