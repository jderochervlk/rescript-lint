module Files = Map.Make (String)

type cached = { source : Source.t; tree : Parser.t }
type stats = { parsed : int; reused : int; overlays : int }

type t = {
  selection : (string * string list) option;
  entries : cached Files.t;
  parse : Source.t -> (Parser.t, Lint_error.t) result;
}

type outcome = {
  cache : t;
  project : (Project_files.t, Lint_error.t) result;
  stats : stats;
}

type progress = {
  entries : cached Files.t;
  stats : stats;
  overlay_failed : bool;
}

let create ~parse = { selection = None; entries = Files.empty; parse }
let empty = create ~parse:Parser.parse
let no_stats = { parsed = 0; reused = 0; overlays = 0 }

let selected root excluded cache =
  let selection = Some (root, List.sort_uniq String.compare excluded) in
  if selection = cache.selection then cache
  else { cache with selection; entries = Files.empty }

let is_overlay overlay source =
  Option.fold ~none:false
    ~some:(fun overlay ->
      Project_files.canonical overlay.Source.filename
      = Project_files.canonical source.Source.filename)
    overlay

let remembered key source entries =
  Option.bind (Files.find_opt key entries) (fun cached ->
      if cached.source = source then Some cached.tree else None)

let disk_result key source entries = function
  | Ok tree -> Files.add key { source; tree } entries
  | Error _ -> Files.remove key entries

let parse_source parse overlay source progress =
  let key = Project_files.canonical source.Source.filename in
  let overlaid = is_overlay overlay source in
  let stats =
    {
      progress.stats with
      overlays = (progress.stats.overlays + if overlaid then 1 else 0);
    }
  in
  match remembered key source progress.entries with
  | Some tree ->
      ( { progress with stats = { stats with reused = stats.reused + 1 } },
        Ok tree )
  | None ->
      let result = parse source in
      let entries =
        if overlaid then progress.entries
        else disk_result key source progress.entries result
      in
      let overlay_failed =
        progress.overlay_failed || (overlaid && Result.is_error result)
      in
      ( {
          entries;
          overlay_failed;
          stats = { stats with parsed = stats.parsed + 1 };
        },
        result )

let retain project entries =
  let discovered =
    List.fold_left
      (fun files unit ->
        Files.add
          (Project_files.canonical unit.Project_files.source.filename)
          () files)
      Files.empty project.Project_files.units
  in
  Files.filter (fun filename _ -> Files.mem filename discovered) entries

let finish cache progress project =
  let entries =
    match project with
    | Ok project -> retain project progress.entries
    | Error _ when progress.overlay_failed -> progress.entries
    | Error _ -> Files.empty
  in
  { cache = { cache with entries }; project; stats = progress.stats }

let load ?overlay ~root ~excluded cache =
  let root = Project_files.canonical root in
  let cache = selected root excluded cache in
  (* Project_files' parser callback is an I/O boundary; state stays local here. *)
  let progress =
    ref { entries = cache.entries; stats = no_stats; overlay_failed = false }
  in
  let parse source =
    let after, result = parse_source cache.parse overlay source !progress in
    progress := after;
    result
  in
  let project = Project_files.load ?overlay ~parse ~root ~excluded () in
  finish cache !progress project
