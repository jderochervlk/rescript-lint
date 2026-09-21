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

let dependency_files rules =
  if Rule_config.enabled rules "no-unhandled-throws" then
    Throws_packages.discover_files
      ~roots:(Rule_config.options rules).throws_dependencies
  else Ok []

let observe_inputs ~rules ~files ~configuration =
  let options = Rule_config.options rules in
  let configuration = Option.to_list options.reanalyze_report @ configuration in
  match options.root with
  | None -> observe (List.sort_uniq String.compare (files @ configuration))
  | Some root -> (
      let configuration =
        Filename.concat root "rescript.json" :: configuration
      in
      let tracked = files @ configuration in
      let discovered =
        Result.bind
          (Project_files.discover ~root ~excluded:options.excluded_paths)
          (fun project ->
            Result.map (List.append project) (dependency_files rules))
      in
      match discovered with
      | Ok project ->
          observe (List.sort_uniq String.compare (project @ tracked))
      | Error error -> failed ~files:tracked (Lint_error.render error))

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
  match Command.parse arguments with
  | Ok (Command.Watch { rules; files; _ }) ->
      observe_inputs ~rules ~files ~configuration
  | Error error -> failed ~files:configuration (Command.error_message error)
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
