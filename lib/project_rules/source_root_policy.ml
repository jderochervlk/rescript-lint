type root = { configured : string; canonical : string }
type t = root list

let absolute path =
  if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path
  else path

let rec canonical path =
  let path = absolute path in
  try Unix.realpath path
  with Unix.Unix_error _ ->
    let directory = Filename.dirname path in
    if directory = path then path
    else Filename.concat (canonical directory) (Filename.basename path)

let directory path =
  try
    let resolved = Unix.realpath (absolute path) in
    if (Unix.stat resolved).st_kind <> Unix.S_DIR then
      Error (path ^ " is not a directory.")
    else (
      ignore (Sys.readdir resolved);
      Ok { configured = path; canonical = resolved })
  with
  | Sys_error detail -> Error ("Cannot read source root " ^ path ^ ": " ^ detail)
  | Unix.Unix_error (error, operation, _) ->
      Error
        ("Cannot resolve source root " ^ path ^ " (" ^ operation ^ "): "
       ^ Unix.error_message error)

let load paths =
  let loaded =
    List.fold_left
      (fun result path ->
        Result.bind result (fun roots ->
            Result.map (fun root -> roots @ [ root ]) (directory path)))
      (Ok []) paths
  in
  Result.bind loaded (fun roots ->
      let canonical = List.map (fun root -> root.canonical) roots in
      if
        List.length canonical
        = List.length (List.sort_uniq String.compare canonical)
      then Ok roots
      else
        Error "forbiddenSourceRoots contains duplicate canonical directories.")

let contains root ~filename =
  Path_boundary.contains ~platform:Path_boundary.native ~root:root.canonical
    (canonical filename)

let matching roots ~filename =
  List.find_opt (fun root -> contains root ~filename) roots

let encode paths = `List (List.map (fun path -> `String path) paths)
