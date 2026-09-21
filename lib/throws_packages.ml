type description = {
  root : string;
  config : Throws_package_config.t;
  sources : string list;
}

type package = { description : description; project : Project_files.t }
type t = package list

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
          (Throws_package_config.decode (Yojson.Basic.from_file filename))
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

let directory_sources root (directory : Throws_package_config.directory) =
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

let validate_descriptions descriptions =
  let names =
    List.map
      (fun package -> package.config.Throws_package_config.name)
      descriptions
  in
  let roots = List.map (fun package -> package.root) descriptions in
  if
    List.length names <> List.length (List.sort_uniq String.compare names)
    || List.length roots <> List.length (List.sort_uniq String.compare roots)
  then
    fail "throwsDependencies"
      "Duplicate dependency package names or canonical roots."
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
          ("Dependency " ^ name
         ^ " requires an explicit throwsDependencies root.")
    | None -> Ok descriptions

let discover roots = Result.bind (collect describe roots) validate_descriptions
let inputs description = config_file description.root :: description.sources

let discover_files ~roots =
  Result.map
    (fun descriptions ->
      List.concat_map inputs descriptions |> List.sort_uniq String.compare)
    (discover roots)

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

let load ~roots = Result.bind (discover roots) (collect load_package)

let files packages =
  List.concat_map (fun package -> inputs package.description) packages
  |> List.sort_uniq String.compare

let unit_names package =
  List.map (fun unit -> unit.Project_files.name) package.project.units
  |> List.sort_uniq String.compare

let exposed_names package =
  match package.description.config.namespace with
  | Some namespace -> [ namespace ]
  | None -> unit_names package

let validate_exports project_modules packages =
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

let public_scope package scope =
  let exported =
    List.fold_left
      (fun exported name ->
        match Throws_scope.module_scope scope [ name ] with
        | None -> exported
        | Some contents -> Throws_scope.add_module name contents exported)
      Throws_scope.empty (unit_names package)
  in
  let public =
    match package.description.config.namespace with
    | None -> exported
    | Some name -> Throws_scope.add_module name exported Throws_scope.empty
  in
  Throws_scope.with_exception_aliases
    (Throws_scope.exception_aliases scope)
    public

let package_name package = package.description.config.name

let rec build ~initial packages stack completed package =
  let name = package_name package in
  if List.mem_assoc name completed then Ok completed
  else if List.mem name stack then
    fail
      (config_file package.description.root)
      ("Cyclic dependency contracts: "
      ^ String.concat " -> " (List.rev (name :: stack)))
  else
    Result.bind
      (List.fold_left
         (fun result name ->
           Result.bind result (fun completed ->
               match
                 List.find_opt
                   (fun package -> package_name package = name)
                   packages
               with
               | None ->
                   fail package.description.root
                     ("Missing explicit dependency " ^ name ^ ".")
               | Some dependency ->
                   build ~initial packages
                     (package_name package :: stack)
                     completed dependency))
         (Ok completed) package.description.config.dependencies)
      (index_package ~initial package)

and index_package ~initial package completed =
  let imported =
    List.fold_left
      (fun scope name ->
        match List.assoc_opt name completed with
        | None -> scope
        | Some contents -> Throws_scope.overlay scope contents)
      initial package.description.config.dependencies
  in
  Result.map
    (fun scope ->
      (package_name package, public_scope package scope) :: completed)
    (Throws_project.declarations ~scope:imported package.project)

let scope ~initial ~project_modules packages =
  Result.bind (validate_exports project_modules packages) (fun () ->
      Result.map
        (fun completed ->
          let aliases =
            List.concat_map
              (fun (_, scope) -> Throws_scope.exception_aliases scope)
              completed
            |> Throws_project.canonical_aliases
          in
          let scope =
            List.fold_left
              (fun scope (_, exported) -> Throws_scope.overlay scope exported)
              initial completed
          in
          Throws_scope.with_exception_aliases aliases scope)
        (List.fold_left
           (fun result package ->
             Result.bind result (fun completed ->
                 build ~initial packages [] completed package))
           (Ok []) packages))
