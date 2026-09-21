let load ~config ~source =
  let options = Rule_config.options config in
  match options.root with
  | None -> Ok None
  | Some root ->
      Result.map Option.some
        (Project_files.load ~overlay:source ~root
           ~excluded:options.excluded_paths ())

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
  | Some project ->
      let explicit =
        Project_files.signatures project
        |> List.filter_map (function
          | [ name ], signature -> Some (name, signature)
          | _ -> None)
      in
      let project_modules =
        List.map (fun unit -> unit.Project_files.name) project.units
        |> List.sort_uniq String.compare
      in
      let initial =
        { base with module_signatures = explicit; project_modules }
      in
      let inferred =
        List.filter_map
          (fun unit ->
            match unit.Project_files.tree with
            | Parser.Implementation structure
              when not (List.mem_assoc unit.name explicit) ->
                Some
                  ( unit.name,
                    Project_signatures.of_structure ~context:initial structure
                  )
            | _ -> None)
          project.units
      in
      { initial with module_signatures = explicit @ inferred }
