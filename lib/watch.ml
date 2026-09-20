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

type snapshot = (string * file_state) list
type dependencies = { observe : string list -> snapshot; sleep : unit -> unit }

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

let observe files = List.map (fun file -> (file, file_state file)) files

let rec loop ~dependencies ~continue ~on_change ~refresh_after_change ~files
    ~initial =
  if continue () then (
    dependencies.sleep ();
    let current = dependencies.observe files in
    let next =
      if current = initial then current
      else (
        on_change ();
        if refresh_after_change then dependencies.observe files else current)
    in
    loop ~dependencies ~continue ~on_change ~refresh_after_change ~files
      ~initial:next)
