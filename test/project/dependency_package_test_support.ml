open Rescript_linter

type fixture = string * Yojson.Basic.t * (string * string) list

let manifest ?namespace ?(dependencies = []) ?(sources = `String "src") name =
  `Assoc
    ([
       ("name", `String name);
       ("sources", sources);
       ("dependencies", `List (List.map (fun name -> `String name) dependencies));
     ]
    @ Option.to_list (Option.map (fun value -> ("namespace", value)) namespace)
    )

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let rec mkdir path =
  if not (Sys.file_exists path) then (
    mkdir (Filename.dirname path);
    Unix.mkdir path 0o700)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let install root (directory, config, files) =
  let package = Filename.concat root directory in
  mkdir (Filename.concat package "src");
  Yojson.Basic.to_file (Filename.concat package "rescript.json") config;
  List.iter
    (fun (name, text) ->
      let filename = Filename.concat package name in
      mkdir (Filename.dirname filename);
      write filename text)
    files;
  package

let temporary fixtures run =
  try
    let root = Filename.temp_file "dependency-packages-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect
      ~finally:(fun () -> remove root)
      (fun () ->
        let roots = List.map (install root) fixtures in
        run root roots)
  with
  | Sys_error detail -> Error detail
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)
