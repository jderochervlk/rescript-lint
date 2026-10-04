type t = { paths : string list; rules : (string * bool) list; cwd : string }

let path_root platform components =
  match (platform, components) with
  | Path_boundary.Windows, "" :: "" :: server :: share :: rest
    when server <> "" && share <> "" ->
      ("//" ^ server ^ "/" ^ share, rest)
  | Path_boundary.Windows, drive :: rest
    when String.length drive = 2 && drive.[1] = ':' ->
      ("/" ^ drive, rest)
  | _ -> ("", components)

let normalize_path ~platform path =
  let path =
    match platform with
    | Path_boundary.Posix -> path
    | Windows ->
        String.map (function '\\' -> '/' | character -> character) path
        |> String.lowercase_ascii
  in
  let root, components = path_root platform (String.split_on_char '/' path) in
  components
  |> List.fold_left
       (fun components -> function
         | "" | "." -> components
         | ".." -> ( match components with [] -> [] | _ :: rest -> rest)
         | component -> component :: components)
       []
  |> List.rev |> String.concat "/"
  |> fun path -> root ^ "/" ^ path

let absolute ~cwd path =
  if Filename.is_relative path then Filename.concat cwd path else path

let matching_path path =
  Path_boundary.resolve path |> normalize_path ~platform:Path_boundary.native

let duplicate names =
  List.length names <> List.length (List.sort_uniq String.compare names)

let invalid_character = function
  | '*' | '?' | '[' | ']' | '{' | '}' | '\\' | '\000' -> true
  | _ -> false

let path ~cwd ~base = function
  | `String value
    when String.trim value <> ""
         && (not (String.starts_with ~prefix:"!" value))
         && (not (String.exists invalid_character value))
         && not (List.mem ".." (String.split_on_char '/' value)) ->
      Ok
        (absolute ~cwd
           (if Filename.is_relative value then Filename.concat base value
            else value))
  | _ ->
      Error
        "Override paths must be nonempty literal paths without parent \
         traversal, globs, or backslashes."

let paths ~cwd ~base = function
  | `List (_ :: _ as values) ->
      let decoded =
        List.fold_left
          (fun result value ->
            Result.bind result (fun paths ->
                Result.map (fun path -> path :: paths) (path ~cwd ~base value)))
          (Ok []) values
      in
      Result.bind decoded (fun paths ->
          if duplicate (List.map matching_path paths) then
            Error "Duplicate override paths are not allowed."
          else Ok (List.rev paths))
  | _ -> Error "Override paths must be a nonempty array."

let rules ~known_ids = function
  | `Assoc (_ :: _ as fields) ->
      if duplicate (List.map fst fields) then
        Error "Duplicate override rule settings are not allowed."
      else
        List.fold_left
          (fun result (id, value) ->
            Result.bind result (fun rules ->
                if not (List.mem id known_ids) then
                  Error ("Unknown override rule: " ^ id)
                else
                  match value with
                  | `Bool enabled -> Ok ((id, enabled) :: rules)
                  | _ ->
                      Error ("Override rule " ^ id ^ " requires true or false.")))
          (Ok []) fields
        |> Result.map List.rev
  | _ -> Error "Override rules must be a nonempty object."

let entry ~cwd ~base ~known_ids = function
  | `Assoc fields ->
      let names = List.map fst fields in
      if duplicate names then
        Error "Duplicate override properties are not allowed."
      else if List.exists (fun name -> name <> "paths" && name <> "rules") names
      then Error "Override entries accept only paths and rules."
      else
        Result.bind
          (paths ~cwd ~base
             (Option.value ~default:`Null (List.assoc_opt "paths" fields)))
          (fun paths ->
            Result.map
              (fun rules -> { paths; rules; cwd })
              (rules ~known_ids
                 (Option.value ~default:`Null (List.assoc_opt "rules" fields))))
  | _ -> Error "Every override must be an object."

let decode ~cwd ~base ~known_ids = function
  | `List values ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun overrides ->
              Result.map
                (fun override -> override :: overrides)
                (entry ~cwd ~base ~known_ids value)))
        (Ok []) values
      |> Result.map List.rev
  | _ -> Error "overrides must be an array."

let matches path filename =
  Path_boundary.contains ~platform:Path_boundary.Posix
    ~root:(matching_path path) filename

let settings_for_file ~filename overrides =
  List.concat_map
    (fun override ->
      let filename = absolute ~cwd:override.cwd filename |> matching_path in
      if List.exists (fun path -> matches path filename) override.paths then
        override.rules
      else [])
    overrides

let matching_index ~filename ~id overrides =
  List.mapi (fun index override -> (index, override)) overrides
  |> List.fold_left
       (fun matched (index, override) ->
         let filename = absolute ~cwd:override.cwd filename |> matching_path in
         if
           List.mem_assoc id override.rules
           && List.exists (fun path -> matches path filename) override.paths
         then Some index
         else matched)
       None
