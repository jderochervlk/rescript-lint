type root = { configured : string; canonical : string }
type t = root list

let absolute path =
  if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path
  else path

let canonical path =
  let path = absolute path in
  try Unix.realpath path
  with Unix.Unix_error _ -> (
    let directory = Filename.dirname path in
    try Filename.concat (Unix.realpath directory) (Filename.basename path)
    with Unix.Unix_error _ -> path)

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

let boundary_prefix ~prefix path =
  path = prefix
  ||
  let length = String.length prefix in
  String.length path > length
  && String.starts_with ~prefix path
  && (prefix.[length - 1] = Filename.dir_sep.[0]
     || path.[length] = Filename.dir_sep.[0])

let contains root ~filename =
  boundary_prefix ~prefix:root.canonical (canonical filename)

let matching roots ~filename =
  List.find_opt (fun root -> contains root ~filename) roots

let encode paths = `List (List.map (fun path -> `String path) paths)
