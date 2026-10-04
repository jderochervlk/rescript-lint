type file_state =
  | Unavailable
  | Available of {
      device : int;
      inode : int;
      kind : Unix.file_kind;
      permissions : int;
      size : int;
      modified_at : float;
      changed_at : float;
    }

type snapshot = { files : (string * file_state) list; failure : string option }
type dependencies = { observe : string list -> snapshot; sleep : unit -> unit }
type dynamic_dependencies = { snapshot : unit -> snapshot; wait : unit -> unit }

let file_state filename =
  try
    let stats = Unix.stat filename in
    Available
      {
        device = stats.st_dev;
        inode = stats.st_ino;
        kind = stats.st_kind;
        permissions = stats.st_perm;
        size = stats.st_size;
        modified_at = stats.st_mtime;
        changed_at = stats.st_ctime;
      }
  with Unix.Unix_error _ -> Unavailable

let observe files =
  {
    files = List.map (fun file -> (file, file_state file)) files;
    failure = None;
  }

let failed ~files message = { (observe files) with failure = Some message }

let enabled_for_files rules files id =
  match files with
  | [] -> Rule_config.enabled rules id
  | _ ->
      List.exists
        (fun filename ->
          Rule_config.enabled (Rule_config.for_file ~filename rules) id)
        files

let discovered_dependencies context roots =
  if roots = [] then Ok []
  else Throws_packages.discover_files_with_context ~context ~roots

let dependency_files rules files =
  let options = Rule_config.options rules in
  let throws =
    if enabled_for_files rules files "no-unhandled-throws" then
      options.throws_dependencies
    else []
  in
  let provenance =
    if enabled_for_files rules files "forbidden-source-root-reference" then
      options.source_root_dependencies
    else []
  in
  Result.bind
    (discovered_dependencies Throws_packages.Throws_dependencies throws)
    (fun throws ->
      Result.map
        (fun provenance -> List.sort_uniq String.compare (throws @ provenance))
        (discovered_dependencies Throws_packages.Source_root_dependencies
           provenance))

let source_root_files rules files =
  if enabled_for_files rules files "forbidden-source-root-reference" then
    (Rule_config.options rules).forbidden_source_roots
  else []

let discovered_inputs ~rules ~files ~root ~excluded =
  Result.bind (Project_files.discover ~root ~excluded) (fun project ->
      let selected = if files = [] then project else files in
      Result.map
        (fun dependencies ->
          project @ source_root_files rules selected @ dependencies)
        (dependency_files rules selected))

let observe_inputs ~rules ~files ~configuration =
  let options = Rule_config.options rules in
  let configuration = Option.to_list options.reanalyze_report @ configuration in
  match options.root with
  | None ->
      observe
        (List.sort_uniq String.compare
           (files @ source_root_files rules files @ configuration))
  | Some root -> (
      let configuration =
        Filename.concat root "rescript.json" :: configuration
      in
      let tracked = files @ configuration in
      let discovered =
        discovered_inputs ~rules ~files ~root ~excluded:options.excluded_paths
      in
      match discovered with
      | Ok project ->
          observe (List.sort_uniq String.compare (project @ tracked))
      | Error error ->
          failed
            ~files:(tracked @ source_root_files rules files)
            (Lint_error.render error))

let rec configuration_files = function
  | [] | "--" :: _ -> []
  | "--config" :: filename :: rest -> filename :: configuration_files rest
  | ( "--enable-rule" | "--disable-rule" | "--project" | "--jsx-runtime"
    | "--test-framework" | "--throws-runtime" | "--format" )
    :: _value :: rest ->
      configuration_files rest
  | _ :: rest -> configuration_files rest

let command_snapshot arguments =
  let configuration = configuration_files arguments in
  match Cli_command.parse arguments with
  | Ok (Cli_command.Watch { rules; files; _ }) ->
      observe_inputs ~rules ~files ~configuration
  | Error error -> failed ~files:configuration (Cli_command.error_message error)
  | Ok _ -> failed ~files:configuration "Expected a watch command."

let rec loop_dynamic ~dependencies ~continue ~on_change ~refresh_after_change
    ~initial =
  if continue () then (
    dependencies.wait ();
    let current = dependencies.snapshot () in
    let next =
      if current = initial then current
      else (
        on_change ();
        if refresh_after_change then dependencies.snapshot () else current)
    in
    loop_dynamic ~dependencies ~continue ~on_change ~refresh_after_change
      ~initial:next)

let loop ~dependencies ~continue ~on_change ~refresh_after_change ~files
    ~initial =
  let dynamic =
    {
      snapshot = (fun () -> dependencies.observe files);
      wait = dependencies.sleep;
    }
  in
  loop_dynamic ~dependencies:dynamic ~continue ~on_change ~refresh_after_change
    ~initial
