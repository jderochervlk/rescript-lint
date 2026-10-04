let fail filename detail = Error (Lint_error.Read_error { filename; detail })
let config_file root = Filename.concat root "rescript.json"

let public_scope (package : Dependency_packages.package) scope =
  let exported =
    List.fold_left
      (fun exported name ->
        match Throws_scope.module_scope scope [ name ] with
        | None -> exported
        | Some contents -> Throws_scope.add_module name contents exported)
      Throws_scope.empty
      (List.map (fun unit -> unit.Project_files.name) package.project.units
      |> List.sort_uniq String.compare)
  in
  let public =
    match package.namespace with
    | None -> exported
    | Some name -> Throws_scope.add_module name exported Throws_scope.empty
  in
  Throws_scope.with_exception_aliases
    (Throws_scope.exception_aliases scope)
    public

let rec build ~initial packages stack completed
    (package : Dependency_packages.package) =
  let name = package.name in
  if List.mem_assoc name completed then Ok completed
  else if List.mem name stack then
    fail
      (config_file package.project.root)
      ("Cyclic dependency contracts: "
      ^ String.concat " -> " (List.rev (name :: stack)))
  else
    Result.bind
      (List.fold_left
         (fun result name ->
           Result.bind result (fun completed ->
               match
                 List.find_opt
                   (fun package -> package.Dependency_packages.name = name)
                   packages
               with
               | None ->
                   fail package.project.root
                     ("Missing explicit dependency " ^ name ^ ".")
               | Some dependency ->
                   build ~initial packages (package.name :: stack) completed
                     dependency))
         (Ok completed) package.dependencies)
      (index_package ~initial package)

and index_package ~initial package completed =
  let imported =
    List.fold_left
      (fun scope name ->
        match List.assoc_opt name completed with
        | None -> scope
        | Some contents -> Throws_scope.overlay scope contents)
      initial package.dependencies
  in
  Result.map
    (fun scope -> (package.name, public_scope package scope) :: completed)
    (Throws_project.declarations ~scope:imported package.project)

let scope ~initial ~project_modules packages =
  Result.bind (Dependency_packages.validate_exports ~project_modules packages)
    (fun packages ->
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
