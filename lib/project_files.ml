type unit_ = {
  name : string;
  source : Source.t;
  tree : Parser.t;
  modified : float;
}

type t = { root : string; units : unit_ list }

let module_name filename =
  Filename.basename filename |> Filename.remove_extension
  |> String.capitalize_ascii

let canonical filename =
  try Unix.realpath filename with Unix.Unix_error _ -> filename

let failure filename detail = Error (Lint_error.Read_error { filename; detail })

let io filename run =
  try run () with
  | Sys_error detail -> failure filename detail
  | Unix.Unix_error (error, operation, _) ->
      failure filename (operation ^ ": " ^ Unix.error_message error)

let excluded_path excluded relative =
  List.exists
    (fun prefix ->
      relative = prefix || String.starts_with ~prefix:(prefix ^ "/") relative)
    excluded

let ignored name =
  List.mem name [ ".git"; "node_modules"; "_build"; "_opam"; ".rescript" ]

let source_path filename =
  List.mem (Filename.extension filename) [ ".res"; ".resi" ]

let rec scan ~root ~excluded ~recursive relative =
  let directory = Filename.concat root relative in
  io directory (fun () ->
      Sys.readdir directory |> Array.to_list |> List.sort String.compare
      |> List.fold_left
           (fun result name ->
             Result.bind result (fun files ->
                 let relative =
                   if relative = "." then name
                   else Filename.concat relative name
                 in
                 if ignored name || excluded_path excluded relative then
                   Ok files
                 else
                   Result.map
                     (fun found -> files @ found)
                     (scan_entry ~root ~excluded ~recursive relative)))
           (Ok []))

and scan_entry ~root ~excluded ~recursive relative =
  let filename = Filename.concat root relative in
  io filename (fun () ->
      match (Unix.lstat filename).st_kind with
      | Unix.S_DIR when recursive -> scan ~root ~excluded ~recursive relative
      | Unix.S_REG when source_path filename -> Ok [ filename ]
      | _ -> Ok [])

let source_directory = function
  | `String directory -> Ok (directory, false)
  | `Assoc fields -> (
      match (List.assoc_opt "dir" fields, List.assoc_opt "subdirs" fields) with
      | Some (`String directory), (None | Some (`Bool false)) ->
          Ok (directory, false)
      | Some (`String directory), Some (`Bool true) -> Ok (directory, true)
      | _ ->
          Error "Each source object requires dir and optional boolean subdirs.")
  | _ -> Error "Invalid project source directory."

let source_directories = function
  | `List entries ->
      List.fold_left
        (fun result entry ->
          Result.bind result (fun dirs ->
              Result.map (fun dir -> dirs @ [ dir ]) (source_directory entry)))
        (Ok []) entries
  | entry -> Result.map (fun dir -> [ dir ]) (source_directory entry)

let read_directories root =
  let filename = Filename.concat root "rescript.json" in
  io filename (fun () ->
      try
        match Yojson.Basic.from_file filename with
        | `Assoc fields -> (
            match List.assoc_opt "sources" fields with
            | Some sources ->
                Result.map_error
                  (fun detail -> Lint_error.Read_error { filename; detail })
                  (source_directories sources)
            | None -> Ok [ ("src", true) ])
        | _ -> failure filename "Project configuration must be an object."
      with Yojson.Json_error detail -> failure filename detail)

let contained root directory =
  let resolved = canonical (Filename.concat root directory) in
  resolved = root || String.starts_with ~prefix:(root ^ "/") resolved

let discover ~root ~excluded =
  let root = canonical root in
  Result.bind (read_directories root) (fun directories ->
      List.fold_left
        (fun result (directory, recursive) ->
          Result.bind result (fun files ->
              if not (contained root directory) then
                failure root
                  "Source directories must stay inside the project root."
              else
                Result.map
                  (fun found -> files @ found)
                  (scan ~root ~excluded ~recursive directory)))
        (Ok []) directories
      |> Result.map (List.sort_uniq String.compare))

let load_unit ~parse overlay filename =
  let source =
    match overlay with
    | Some source when canonical source.Source.filename = canonical filename ->
        Ok source
    | _ -> Source.read filename
  in
  Result.bind source (fun source ->
      Result.bind (parse source) (fun tree ->
          io filename (fun () ->
              Ok
                {
                  name = module_name filename;
                  source;
                  tree;
                  modified = (Unix.stat filename).st_mtime;
                })))

let duplicate_units units =
  let keys =
    List.map (fun unit -> (unit.name, unit.source.Source.kind)) units
  in
  List.length keys <> List.length (List.sort_uniq compare keys)

let load ?overlay ?(parse = Parser.parse) ~root ~excluded () =
  let root = canonical root in
  Result.bind (discover ~root ~excluded) (fun files ->
      let loaded =
        List.fold_left
          (fun result file ->
            Result.bind result (fun units ->
                Result.map
                  (fun unit -> unit :: units)
                  (load_unit ~parse overlay file)))
          (Ok []) files
      in
      Result.bind loaded (fun units ->
          if duplicate_units units then
            failure root "Ambiguous project module names."
          else Ok { root; units = List.rev units }))

let signature project name =
  List.find_map
    (fun unit ->
      match unit.tree with
      | Parser.Interface signature when unit.name = name -> Some signature
      | _ -> None)
    project.units

let signatures project =
  List.filter_map
    (fun unit ->
      match unit.tree with
      | Parser.Interface signature -> Some ([ unit.name ], signature)
      | _ -> None)
    project.units

let has_interface project unit = Option.is_some (signature project unit.name)
