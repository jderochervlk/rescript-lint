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

let project_signatures ~(context : Semantic_model.context)
    (project : Project_files.t) =
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
  let infer signatures =
    let context =
      {
        context with
        module_signatures = context.module_signatures @ signatures;
        project_modules =
          List.sort_uniq String.compare
            (context.project_modules
            @ List.map (fun unit -> unit.Project_files.name) project.units);
      }
    in
    List.map
      (fun (name, structure) ->
        (name, Project_signatures.of_structure ~context structure))
      implementations
  in
  let rec settle remaining inferred =
    if remaining = 0 then inferred
    else
      let next = infer (explicit @ inferred) in
      if next = inferred then next else settle (remaining - 1) next
  in
  explicit @ settle (List.length implementations + 1) []

let module_item (name, signature) =
  Ast_helper.Sig.module_
    (Ast_helper.Md.mk (Location.mknoloc name)
       (Ast_helper.Mty.signature signature))

let dependency_signatures context (package : Throws_packages.semantic_package) =
  let signatures = project_signatures ~context package.project in
  match package.namespace with
  | None -> signatures
  | Some namespace -> [ (namespace, List.map module_item signatures) ]

let all_dependency_signatures (context : Semantic_model.context) packages =
  let rec settle remaining signatures =
    if remaining = 0 then signatures
    else
      let dependency_modules = List.map fst signatures in
      let nested =
        {
          context with
          module_signatures = context.module_signatures @ signatures;
          project_modules =
            List.sort_uniq String.compare
              (context.project_modules @ dependency_modules);
        }
      in
      let next = List.concat_map (dependency_signatures nested) packages in
      if next = signatures then next else settle (remaining - 1) next
  in
  settle (List.length packages + 1) []

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
      let module_signatures = project_signatures ~context:initial project in
      { initial with module_signatures }

let dependency_context context project packages =
  let signatures = all_dependency_signatures context packages in
  let modules = List.map fst signatures in
  let context =
    {
      context with
      Semantic_model.module_signatures = signatures;
      project_modules =
        List.sort_uniq String.compare (context.project_modules @ modules);
    }
  in
  let project_signatures = project_signatures ~context project in
  { context with module_signatures = signatures @ project_signatures }

let semantic_with_dependencies ~config ~source project =
  let context = semantic ~config ~source project in
  let options = Rule_config.options config in
  match project with
  | None -> Ok context
  | Some _
    when (not (Rule_config.enabled config "forbidden-source-root-reference"))
         || options.source_root_dependencies = [] ->
      Ok context
  | Some project ->
      Result.bind
        (Result.map_error (provenance_error source)
           (Throws_packages.load ~roots:options.source_root_dependencies))
        (fun packages ->
          Result.map_error (provenance_error source)
            (Result.map
               (dependency_context context project)
               (Throws_packages.semantic_packages
                  ~project_modules:context.project_modules packages)))
