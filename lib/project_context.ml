let load ~config ~source =
  let options = Rule_config.options config in
  match options.root with
  | None -> Ok None
  | Some root ->
      Result.map Option.some
        (Project_files.load ~overlay:source ~root
           ~excluded:options.excluded_paths ())

let load_cached cache ~config ~source =
  let options = Rule_config.options config in
  match options.root with
  | None -> (cache, Ok None)
  | Some root ->
      let loaded =
        Project_index.load ~overlay:source ~root
          ~excluded:options.excluded_paths cache
      in
      (loaded.cache, Result.map Option.some loaded.project)

let combine_signatures groups =
  (List.concat_map fst groups, List.concat_map snd groups)

let extend_context (context : Semantic_model.context) (signatures, origins) =
  {
    context with
    module_signatures = context.module_signatures @ signatures;
    value_origins = origins @ context.value_origins;
    project_modules =
      List.sort_uniq String.compare
        (context.project_modules @ List.map fst signatures);
  }

let project_inputs (project : Project_files.t) =
  let explicit =
    Project_files.signatures project
    |> List.filter_map (function
      | [ name ], signature -> Some (name, signature)
      | _ -> None)
  in
  let implementations =
    List.filter_map
      (fun unit ->
        match unit.Project_files.tree with
        | Parser.Implementation structure
          when not (List.mem_assoc unit.name explicit) ->
            Some (unit.name, structure)
        | Implementation _ | Interface _ -> None)
      project.Project_files.units
  in
  (explicit, implementations)

let infer_signatures context implementations =
  List.map
    (fun (name, structure) ->
      let signature, origins =
        Project_signatures.of_structure_with_origins ~context structure
      in
      ( [ (name, signature) ],
        List.map (fun (path, origin) -> (name :: path, origin)) origins ))
    implementations
  |> combine_signatures

let local_context (context : Semantic_model.context) (project : Project_files.t)
    =
  let modules = List.map (fun unit -> unit.Project_files.name) project.units in
  let imported name = not (List.mem name modules) in
  {
    context with
    module_signatures =
      List.filter (fun (name, _) -> imported name) context.module_signatures;
    value_origins =
      List.filter
        (fun (path, _) ->
          match path with [] -> true | name :: _ -> imported name)
        context.value_origins;
    project_modules =
      List.sort_uniq String.compare (context.project_modules @ modules);
  }

let module_item (name, signature) =
  Ast_helper.Sig.module_
    (Ast_helper.Md.mk (Location.mknoloc name)
       (Ast_helper.Mty.signature signature))

let with_namespace namespace (signatures, origins) =
  match namespace with
  | None -> (signatures, origins)
  | Some name ->
      ( signatures @ [ (name, List.map module_item signatures) ],
        origins
        @ List.map (fun (path, origin) -> (name :: path, origin)) origins )

let project_signatures ?namespace ~context project =
  let explicit, implementations = project_inputs project in
  let context = local_context context project in
  let rec settle remaining inferred =
    if remaining = 0 then inferred
    else
      let nested =
        extend_context context
          (with_namespace namespace
             (combine_signatures [ (explicit, []); inferred ]))
      in
      let next = infer_signatures nested implementations in
      if next = inferred then next else settle (remaining - 1) next
  in
  with_namespace namespace
    (combine_signatures
       [ (explicit, []); settle (List.length implementations + 1) ([], []) ])

let dependency_signatures context (package : Throws_packages.semantic_package) =
  let signatures, origins = project_signatures ~context package.project in
  match package.namespace with
  | None -> (signatures, origins)
  | Some namespace ->
      ( [ (namespace, List.map module_item signatures) ],
        List.map (fun (path, origin) -> (namespace :: path, origin)) origins )

let package_roots (package : Throws_packages.semantic_package) =
  match package.namespace with
  | Some namespace -> [ namespace ]
  | None ->
      List.map (fun unit -> unit.Project_files.name) package.project.units
      |> List.sort_uniq String.compare

let dependency_closure packages names =
  let rec visit completed = function
    | [] -> completed
    | name :: rest when List.mem name completed -> visit completed rest
    | name :: rest ->
        let dependencies =
          List.find_map
            (fun (package : Throws_packages.semantic_package) ->
              if package.name = name then Some package.dependencies else None)
            packages
          |> Option.value ~default:[]
        in
        visit (name :: completed) (dependencies @ rest)
  in
  visit [] names

let isolated_dependency_context context packages groups
    (package : Throws_packages.semantic_package) =
  let permitted = dependency_closure packages package.dependencies in
  let declarations =
    List.filter_map
      (fun (name, declarations) ->
        if List.mem name permitted then Some declarations else None)
      groups
    |> combine_signatures
  in
  extend_context
    {
      context with
      Semantic_model.project_modules = List.concat_map package_roots packages;
    }
    declarations

let blocked_package_roots packages (package : Throws_packages.semantic_package)
    =
  let permitted =
    package.name :: dependency_closure packages package.dependencies
  in
  let local =
    List.map (fun unit -> unit.Project_files.name) package.project.units
  in
  List.filter_map
    (fun (dependency : Throws_packages.semantic_package) ->
      if List.mem dependency.name permitted then None
      else Some (package_roots dependency))
    packages
  |> List.concat
  |> List.filter (fun name -> not (List.mem name local))

(* A configured root is known; its declarations are unavailable without an edge. *)
let blocked_scope name = { Semantic_model.unknown with origin = Some [ name ] }

let blocked_reference blocked scope identifier =
  match Semantic_model.path identifier with
  | Some (name :: _) when List.mem name blocked -> (
      match Semantic_model.Names.find_opt name scope.Semantic_model.modules with
      | Some nested when nested = blocked_scope name -> Some name
      | None when scope.opaque -> Some name
      | Some _ | None -> None)
  | Some _ | None -> None

let edge_callbacks blocked references =
  let inspect scope identifier =
    Option.iter
      (fun name -> references := name :: !references)
      (blocked_reference blocked scope identifier)
  in
  {
    Semantic_walk.nothing with
    expression =
      (fun scope expression ->
        match expression.Parsetree.pexp_desc with
        | Pexp_ident identifier -> inspect scope identifier.txt
        | _ -> ());
    core_type =
      (fun scope typ ->
        match typ.Parsetree.ptyp_desc with
        | Ptyp_constr (identifier, _) -> inspect scope identifier.txt
        | _ -> ());
    module_reference = (fun scope identifier -> inspect scope identifier.txt);
  }

let validate_package_edges context packages
    (package : Throws_packages.semantic_package) =
  let blocked = blocked_package_roots packages package in
  let scope =
    List.fold_left
      (fun scope name ->
        Semantic_model.add_module name (blocked_scope name) scope)
      (Semantic_model.initial context)
      blocked
  in
  List.fold_left
    (fun result (unit : Project_files.unit_) ->
      Result.bind result (fun () ->
          if
            unit.source.kind = Source.Implementation
            && Project_files.has_interface package.project unit
          then Ok ()
          else
            let references = ref [] in
            Semantic_walk.iter
              (edge_callbacks blocked references)
              scope unit.tree;
            match List.rev !references with
            | [] -> Ok ()
            | name :: _ ->
                Error
                  (Lint_error.Read_error
                     {
                       filename = unit.source.filename;
                       detail =
                         "Package " ^ package.name ^ " references module "
                         ^ name ^ " without a declared dependency edge.";
                     })))
    (Ok ()) package.project.units

let dependency_base (context : Semantic_model.context) packages =
  {
    context with
    module_signatures = [];
    value_origins = [];
    project_modules = [];
    namespace_roots =
      List.filter_map
        (fun package -> package.Throws_packages.namespace)
        packages;
  }

let settle_dependencies context packages =
  let rec settle remaining groups =
    if remaining = 0 then groups
    else
      let next =
        List.map
          (fun (package : Throws_packages.semantic_package) ->
            let nested =
              isolated_dependency_context context packages groups package
            in
            (package.name, dependency_signatures nested package))
          packages
      in
      if next = groups then next else settle (remaining - 1) next
  in
  settle (List.length packages + 1) []

let validate_dependency_groups context packages groups =
  List.fold_left
    (fun result package ->
      Result.bind result (fun () ->
          let nested =
            isolated_dependency_context context packages groups package
          in
          let nested =
            extend_context nested
              (project_signatures ~context:nested package.project)
          in
          validate_package_edges nested packages package))
    (Ok ()) packages

let all_dependency_signatures context packages =
  let context = dependency_base context packages in
  let groups = settle_dependencies context packages in
  Result.map
    (fun () -> List.map snd groups |> combine_signatures)
    (validate_dependency_groups context packages groups)

let provenance_error source error =
  let point = Diagnostic.{ line = 1; column = 1; byte_offset = 0 } in
  Lint_error.Analysis_errors
    ( Diagnostic.
        {
          filename = source.Source.filename;
          rule = "source-root-analysis";
          message = Lint_error.render error;
          help = None;
          symbol = None;
          fixes = [];
          range = { start = point; finish = point };
        },
      [] )

let semantic ~config ~source project =
  let options = Rule_config.options config in
  let base =
    {
      Semantic_model.default_context with
      enabled = Rule_config.enabled_ids config;
      entry_module =
        List.mem
          (Project_files.module_name source.Source.filename)
          options.entry_modules;
      deep_equality_threshold = options.deep_equality_threshold;
    }
  in
  match project with
  | None -> base
  | Some (project : Project_files.t) ->
      let project_modules =
        List.map (fun unit -> unit.Project_files.name) project.units
        |> List.sort_uniq String.compare
      in
      let initial = { base with project_modules } in
      extend_context initial (project_signatures ~context:initial project)

let dependency_context namespace context project packages =
  let dependency_base =
    {
      context with
      Semantic_model.module_signatures = [];
      value_origins = [];
      namespace_roots =
        Option.to_list namespace
        @ List.filter_map
            (fun package -> package.Throws_packages.namespace)
            packages;
    }
  in
  Result.map
    (fun declarations ->
      let context = extend_context dependency_base declarations in
      extend_context context (project_signatures ?namespace ~context project))
    (all_dependency_signatures context packages)

let semantic_with_dependencies ~config ~source project =
  let context = semantic ~config ~source project in
  let options = Rule_config.options config in
  match project with
  | None -> Ok context
  | Some _
    when not (Rule_config.enabled config "forbidden-source-root-reference") ->
      Ok context
  | Some project ->
      Result.bind
        (Result.map_error (provenance_error source)
           (Project_files.namespace project.root))
        (fun namespace ->
          let context =
            { context with namespace_roots = Option.to_list namespace }
          in
          let project_modules =
            context.project_modules @ Option.to_list namespace
          in
          let loaded =
            match namespace with
            | Some name when List.mem name context.project_modules ->
                Error
                  (Lint_error.Read_error
                     {
                       filename = project.root;
                       detail =
                         "Project namespace collides with module " ^ name ^ ".";
                     })
            | _ ->
                Throws_packages.load_with_context
                  ~context:Throws_packages.Source_root_dependencies
                  ~roots:options.source_root_dependencies
          in
          Result.bind
            (Result.map_error (provenance_error source) loaded)
            (fun packages ->
              Result.map_error (provenance_error source)
                (Result.bind
                   (Throws_packages.semantic_packages ~project_modules packages)
                   (dependency_context namespace context project))))
