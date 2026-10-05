open Project_rule_support

let rule_ids =
  [
    No_restricted_modules.metadata.id;
    Forbidden_source_root_reference.metadata.id;
    No_unused_export.metadata.id;
    No_deprecated_api.metadata.id;
    Require_interface.metadata.id;
    Require_license_header.metadata.id;
  ]

let inspect_policy ~source ~config emit kind path location =
  if Rule_config.enabled config "no-restricted-modules" then
    No_restricted_modules.inspect_policy ~source
      ~options:(Rule_config.options config)
      emit kind path location

let inspect_reference ~source ~config emit scope identifier location =
  if Rule_config.enabled config "no-deprecated-api" then
    No_deprecated_api.inspect ~source emit scope identifier location;
  Option.iter
    (fun path ->
      inspect_policy ~source ~config emit Diagnostic.Value path location)
    (canonical_reference scope identifier)

let source_root_policy ~source ~config project =
  if Rule_config.enabled config "forbidden-source-root-reference" then
    Forbidden_source_root_reference.source_root_policy ~source
      ~options:(Rule_config.options config)
      project
  else Ok None

let reference_findings ~source ~config ~context tree =
  let diagnostics = ref [] in
  let emit diagnostic = diagnostics := diagnostic :: !diagnostics in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression =
        (fun scope expression ->
          match expression.Parsetree.pexp_desc with
          | Pexp_ident identifier ->
              inspect_reference ~source ~config emit scope identifier.txt
                identifier.loc
          | _ -> ());
      module_reference =
        (fun scope identifier ->
          Option.iter
            (fun path ->
              inspect_policy ~source ~config emit Diagnostic.Module path
                identifier.Location.loc)
            (Semantic_model.module_identity scope identifier.txt));
      core_type =
        (fun scope typ ->
          match typ.Parsetree.ptyp_desc with
          | Ptyp_constr (identifier, _) ->
              Option.iter
                (fun path ->
                  inspect_policy ~source ~config emit Diagnostic.Type path
                    identifier.loc)
                (Semantic_model.type_identity scope identifier.txt)
          | _ -> ());
    }
  in
  Semantic_walk.iter callbacks (Semantic_runtime.initial_scope context) tree;
  List.rev !diagnostics

let project_findings ~source ~config project =
  let interfaces = Rule_config.enabled config "require-interface" in
  let unused = Rule_config.enabled config "no-unused-export" in
  if not (interfaces || unused) then Ok []
  else
    match project with
    | None ->
        failure source
          "Project rules require --project DIR or a configured root."
    | Some project ->
        let interface =
          if interfaces then
            Require_interface.interface_findings ~source project
          else []
        in
        Result.map
          (fun findings -> interface @ findings)
          (if unused then
             No_unused_export.unused_findings ~source
               (Rule_config.options config)
               project
           else Ok [])

let check ~config ~context ~project ~source document =
  let validation =
    if Rule_config.enabled config "no-restricted-modules" then
      No_restricted_modules.validate ~source (Rule_config.options config)
    else Ok ()
  in
  Result.bind validation (fun () ->
      Result.bind (source_root_policy ~source ~config project) (fun roots ->
          Result.bind
            (match roots with
            | None -> Ok []
            | Some roots ->
                Forbidden_source_root_reference.source_root_findings ~source
                  ~context roots document.Parser.tree)
            (fun source_roots ->
              Result.map
                (fun findings ->
                  let license =
                    if Rule_config.enabled config "require-license-header" then
                      Require_license_header.license_findings ~source
                        (Rule_config.options config)
                        document
                    else []
                  in
                  Source_range.sort
                    (findings @ license @ source_roots
                    @ reference_findings ~source ~config ~context
                        document.Parser.tree))
                (project_findings ~source ~config project))))
