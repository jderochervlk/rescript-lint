type description = {
  root : string;
  config : Package_config.t;
  sources : string list;
}

type loaded_package = { description : description; project : Project_files.t }
type t = loaded_package list

type package = {
  name : string;
  dependencies : string list;
  namespace : string option;
  project : Project_files.t;
}

type option_context = Throws_dependencies | Source_root_dependencies

let option_name = function
  | Throws_dependencies -> "throwsDependencies"
  | Source_root_dependencies -> "sourceRootDependencies"

let fail filename detail = Error (Lint_error.Read_error { filename; detail })

let io filename run =
  try run () with
  | Sys_error detail -> fail filename detail
  | Unix.Unix_error (error, operation, _) ->
      fail filename (operation ^ ": " ^ Unix.error_message error)

let collect run values =
  List.fold_left
    (fun result value ->
      Result.bind result (fun previous ->
          Result.map (fun next -> previous @ [ next ]) (run value)))
    (Ok []) values

let config_file root = Filename.concat root "rescript.json"

let read_config root =
  let filename = config_file root in
  io filename (fun () ->
      try
        Result.map_error
          (fun detail -> Lint_error.Read_error { filename; detail })
          (Package_config.decode (Yojson.Basic.from_file filename))
      with Yojson.Json_error detail ->
        fail filename ("Invalid dependency JSON: " ^ detail))

let source_file path = List.mem (Filename.extension path) [ ".res"; ".resi" ]

let ignored name =
  List.mem name [ "node_modules"; ".git"; "_build"; "_opam"; ".rescript" ]

let rec scan recursive directory =
  io directory (fun () ->
      let names =
        Sys.readdir directory |> Array.to_list |> List.sort String.compare
      in
      Result.map List.concat (collect (scan_entry recursive directory) names))

and scan_entry recursive directory name =
  if ignored name then Ok []
  else
    let path = Filename.concat directory name in
    io path (fun () ->
        match (Unix.lstat path).st_kind with
        | Unix.S_DIR when recursive -> scan recursive path
        | Unix.S_LNK ->
            fail path
              "Dependency source symlinks are unsupported; configure a \
               canonical package root."
        | Unix.S_REG when source_file path -> Ok [ path ]
        | _ -> Ok [])

let directory_sources root (directory : Package_config.directory) =
  let path = Filename.concat root directory.path in
  io path (fun () ->
      let resolved = Unix.realpath path in
      if
        resolved <> root
        && not (String.starts_with ~prefix:(root ^ "/") resolved)
      then
        fail path
          "Dependency source directories must remain inside their package root."
      else scan directory.recursive resolved)

let describe root =
  io root (fun () ->
      let root = Unix.realpath root in
      Result.bind (read_config root) (fun config ->
          Result.map
            (fun groups ->
              {
                root;
                config;
                sources = List.sort_uniq String.compare (List.concat groups);
              })
            (collect (directory_sources root) config.directories)))

let validate_descriptions context descriptions =
  let option = option_name context in
  let names =
    List.map (fun package -> package.config.Package_config.name) descriptions
  in
  let roots = List.map (fun package -> package.root) descriptions in
  if
    List.length names <> List.length (List.sort_uniq String.compare names)
    || List.length roots <> List.length (List.sort_uniq String.compare roots)
  then fail option "Duplicate dependency package names or canonical roots."
  else
    let missing =
      List.find_map
        (fun package ->
          List.find_map
            (fun name ->
              if List.mem name names then None else Some (package, name))
            package.config.dependencies)
        descriptions
    in
    match missing with
    | Some (package, name) ->
        fail (config_file package.root)
          ("Dependency " ^ name ^ " requires an explicit " ^ option ^ " root.")
    | None -> Ok descriptions

let discover context roots =
  Result.bind (collect describe roots) (validate_descriptions context)

let inputs description = config_file description.root :: description.sources

let discover_files ~context ~roots =
  Result.map
    (fun descriptions ->
      List.concat_map inputs descriptions |> List.sort_uniq String.compare)
    (discover context roots)

let valid_module_name name =
  String.length name > 0
  && (match name.[0] with 'A' .. 'Z' -> true | _ -> false)
  && String.for_all
       (function
         | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' -> true | _ -> false)
       name

let load_unit filename =
  let name = Project_files.module_name filename in
  if not (valid_module_name name) then
    fail filename "Exotic dependency module names are unsupported."
  else
    Result.bind (Source.read filename) (fun source ->
        Result.bind (Parser.parse source) (fun tree ->
            io filename (fun () ->
                Ok
                  Project_files.
                    {
                      name;
                      source;
                      tree;
                      modified = (Unix.stat filename).st_mtime;
                    })))

let load_package description =
  Result.bind (collect load_unit description.sources) (fun units ->
      let keys =
        List.map (fun unit -> (unit.Project_files.name, unit.source.kind)) units
      in
      if List.length keys <> List.length (List.sort_uniq compare keys) then
        fail description.root "Ambiguous dependency module names."
      else
        Ok
          {
            description;
            project = Project_files.{ root = description.root; units };
          })

let load ~context ~roots =
  Result.bind (discover context roots) (collect load_package)

let files packages =
  List.concat_map (fun package -> inputs package.description) packages
  |> List.sort_uniq String.compare

let unit_names (package : loaded_package) =
  List.map (fun unit -> unit.Project_files.name) package.project.units
  |> List.sort_uniq String.compare

let exposed_names (package : loaded_package) =
  match package.description.config.namespace with
  | Some namespace -> [ namespace ]
  | None -> unit_names package

let check_exports project_modules packages =
  let rec walk known = function
    | [] -> Ok ()
    | package :: rest -> (
        let names = exposed_names package in
        match List.find_opt (fun name -> List.mem name known) names with
        | Some name ->
            fail package.description.root
              ("Ambiguous public dependency module root " ^ name ^ ".")
        | None -> walk (names @ known) rest)
  in
  walk project_modules packages

let validate_graph packages =
  let rec visit completed stack package =
    let name = package.description.config.name in
    if List.mem name completed then Ok completed
    else if List.mem name stack then
      fail
        (config_file package.description.root)
        ("Cyclic dependency declarations: "
        ^ String.concat " -> " (List.rev (name :: stack)))
    else
      Result.map
        (fun completed -> name :: completed)
        (List.fold_left
           (fun result dependency ->
             Result.bind result (fun completed ->
                 match
                   List.find_opt
                     (fun package ->
                       package.description.config.name = dependency)
                     packages
                 with
                 | Some package -> visit completed (name :: stack) package
                 | None ->
                     fail
                       (config_file package.description.root)
                       ("Missing explicit dependency " ^ dependency ^ ".")))
           (Ok completed) package.description.config.dependencies)
  in
  Result.map
    (fun _ -> ())
    (List.fold_left
       (fun result package ->
         Result.bind result (fun completed -> visit completed [] package))
       (Ok []) packages)

let parsed_packages packages =
  List.map
    (fun package ->
      {
        name = package.description.config.name;
        dependencies = package.description.config.dependencies;
        namespace = package.description.config.namespace;
        project = package.project;
      })
    packages

let validate_exports ~project_modules packages =
  Result.map
    (fun () -> parsed_packages packages)
    (check_exports project_modules packages)

let validate ~project_modules packages =
  Result.bind (check_exports project_modules packages) (fun () ->
      Result.map (fun () -> parsed_packages packages) (validate_graph packages))
