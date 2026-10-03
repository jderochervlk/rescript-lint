let rule_ids =
  [
    "no-restricted-modules";
    "forbidden-source-root-reference";
    "no-unused-export";
    "no-deprecated-api";
    "require-interface";
    "require-license-header";
  ]

let origin = Diagnostic.{ line = 1; column = 1; byte_offset = 0 }

let diagnostic source rule message location =
  Diagnostic.
    {
      filename = source.Source.filename;
      rule;
      message;
      help = None;
      symbol = None;
      fixes = [];
      range = Source_range.of_location ~source:source.text location;
    }

let file_diagnostic source rule message =
  Diagnostic.
    {
      filename = source.Source.filename;
      rule;
      message;
      help = None;
      symbol = None;
      fixes = [];
      range = { start = origin; finish = origin };
    }

let failure source message =
  Error
    (Lint_error.Analysis_errors
       (file_diagnostic source "project-analysis" message, []))

let analysis_failure source message =
  Error
    (Lint_error.Analysis_errors
       (file_diagnostic source "source-root-analysis" message, []))

let deprecated attributes =
  List.find_map
    (fun (name, payload) ->
      if name.Location.txt <> "deprecated" then None
      else
        Some
          (match payload with
          | Parsetree.PStr
              [
                {
                  pstr_desc =
                    Pstr_eval
                      ( {
                          pexp_desc = Pexp_constant (Pconst_string (message, _));
                          _;
                        },
                        _ );
                  _;
                };
              ] ->
              message
          | _ -> "Use the supported replacement API."))
    attributes

let inspect_policy ~source ~config emit kind path location =
  if Rule_config.enabled config "no-restricted-modules" then
    let options = Rule_config.options config in
    let path = String.concat "." path in
    Option.iter
      (fun entry ->
        let finding =
          diagnostic source "no-restricted-modules"
            ("This reference is restricted: " ^ path ^ ".")
            location
        in
        emit
          {
            finding with
            help = Restriction_policy.guidance entry;
            symbol = Some Diagnostic.{ kind; path };
          })
      (Restriction_policy.matching ~legacy:options.restricted_modules
         options.restrictions ~kind ~path)

let canonical_reference scope identifier =
  match Semantic_model.resolve scope identifier with
  | Some value when Option.is_some value.canonical -> value.canonical
  | _ -> (
      match Semantic_model.path identifier with
      | Some (root :: rest) ->
          Option.map
            (fun path -> path @ rest)
            (Semantic_model.module_identity scope (Longident.Lident root))
      | _ -> None)

let inspect_reference ~source ~config emit scope identifier location =
  if Rule_config.enabled config "no-deprecated-api" then
    Option.iter
      (fun value ->
        Option.iter
          (fun message ->
            emit
              (diagnostic source "no-deprecated-api"
                 ("This API is deprecated. " ^ message)
                 location))
          (deprecated value.Semantic_model.attributes))
      (Semantic_model.resolve scope identifier);
  Option.iter
    (fun path ->
      inspect_policy ~source ~config emit Diagnostic.Value path location)
    (canonical_reference scope identifier)

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
  Semantic_walk.iter callbacks (Semantic_model.initial context) tree;
  List.rev !diagnostics

let provenance_path scope kind identifier =
  match kind with
  | Diagnostic.Value -> (
      match canonical_reference scope identifier with
      | Some path -> path
      | None -> Option.value ~default:[] (Semantic_model.path identifier))
  | Type -> (
      match Semantic_model.type_identity scope identifier with
      | Some path -> path
      | None -> Option.value ~default:[] (Semantic_model.path identifier))
  | Module -> []

let provenance scope kind identifier =
  match kind with
  | Diagnostic.Value -> Semantic_model.value_provenance scope identifier
  | Type -> Semantic_model.type_provenance scope identifier
  | Module -> Semantic_model.Absent

let source_root_finding ~(source : Source.t) root kind path location =
  let label =
    match kind with
    | Diagnostic.Value -> "value"
    | Type -> "type"
    | Module -> "module"
  in
  let symbol = String.concat "." path in
  let finding =
    diagnostic source "forbidden-source-root-reference"
      (Printf.sprintf
         "This %s reference resolves to a declaration in forbidden source root \
          %s: %s."
         label root.Source_root_policy.configured symbol)
      location
  in
  {
    finding with
    help =
      Some
        Diagnostic.
          {
            message =
              "Use a declaration outside this source root, or keep the \
               consumer inside the same root.";
            url = None;
          };
    symbol = Some Diagnostic.{ kind; path = symbol };
  }

let inspect_source_root ~(source : Source.t) ~roots diagnostics unavailable
    scope kind identifier location =
  match provenance scope kind identifier with
  | Semantic_model.Declared_at declaration -> (
      match Source_root_policy.matching roots ~filename:declaration with
      | Some root
        when not (Source_root_policy.contains root ~filename:source.filename) ->
          source_root_finding ~source root kind
            (provenance_path scope kind identifier)
            location
          :: diagnostics
      | Some _ | None -> diagnostics)
  | Unavailable ->
      let path =
        Option.value ~default:"<unresolved>"
          (Option.map (String.concat ".") (Semantic_model.path identifier))
      in
      unavailable :=
        diagnostic source "source-root-analysis"
          ("Declaration origin is unavailable for " ^ path
         ^ "; forbidden-source-root-reference cannot analyze this reference.")
          location
        :: !unavailable;
      diagnostics
  | Absent | External -> diagnostics

let source_root_findings ~source ~context roots tree =
  let diagnostics = ref [] in
  let unavailable = ref [] in
  let inspect scope kind identifier location =
    diagnostics :=
      inspect_source_root ~source ~roots !diagnostics unavailable scope kind
        identifier location
  in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression =
        (fun scope expression ->
          match expression.Parsetree.pexp_desc with
          | Pexp_ident identifier ->
              inspect scope Diagnostic.Value identifier.txt identifier.loc
          | _ -> ());
      core_type =
        (fun scope typ ->
          match typ.Parsetree.ptyp_desc with
          | Ptyp_constr (identifier, _) ->
              inspect scope Diagnostic.Type identifier.txt identifier.loc
          | _ -> ());
    }
  in
  Semantic_walk.iter callbacks (Semantic_model.initial context) tree;
  match List.rev !unavailable with
  | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
  | [] -> Ok (List.rev !diagnostics)

let source_root_policy ~source ~config project =
  if not (Rule_config.enabled config "forbidden-source-root-reference") then
    Ok None
  else
    let options = Rule_config.options config in
    match (options.root, project, options.forbidden_source_roots) with
    | None, _, _ ->
        analysis_failure source
          "forbidden-source-root-reference requires --project DIR or a \
           configured root."
    | Some _, None, _ ->
        analysis_failure source
          "forbidden-source-root-reference requires available project \
           declarations."
    | Some _, Some _, [] ->
        analysis_failure source
          "forbidden-source-root-reference requires nonempty \
           forbiddenSourceRoots."
    | Some _, Some _, roots ->
        Result.map Option.some
          (Result.map_error
             (fun message ->
               Lint_error.Analysis_errors
                 (file_diagnostic source "source-root-analysis" message, []))
             (Source_root_policy.load roots))

let license_comment license comment =
  Res_comment.txt comment |> String.split_on_char '\n'
  |> List.exists (fun line ->
      let line = String.trim line in
      let line =
        if String.starts_with ~prefix:"*" line then
          String.sub line 1 (String.length line - 1) |> String.trim
        else line
      in
      line = "SPDX-License-Identifier: " ^ license)

let first_item = function
  | Parser.Implementation (item :: _) ->
      item.Parsetree.pstr_loc.loc_start.pos_cnum
  | Interface (item :: _) -> item.Parsetree.psig_loc.loc_start.pos_cnum
  | _ -> max_int

let license_findings ~source options document =
  let first = first_item document.Parser.tree in
  let header =
    List.exists
      (fun comment ->
        (Res_comment.loc comment).loc_end.pos_cnum <= first
        && license_comment options.Project_options.license comment)
      document.comments
  in
  if header then []
  else
    [
      file_diagnostic source "require-license-header"
        ("Add a leading SPDX-License-Identifier: " ^ options.license
       ^ " comment.");
    ]

let interface_findings ~source project =
  match source.Source.kind with
  | Interface -> []
  | Implementation ->
      let exists =
        List.exists
          (fun unit ->
            Project_files.canonical unit.Project_files.source.filename
            = Project_files.canonical source.filename
            && Project_files.has_interface project unit)
          project.Project_files.units
      in
      if exists then []
      else
        [
          file_diagnostic source "require-interface"
            "Add a matching .resi interface for this implementation.";
        ]

let unused_findings ~source options project =
  if
    List.mem
      (Project_files.module_name source.Source.filename)
      options.Project_options.entry_modules
  then Ok []
  else
    match options.reanalyze_report with
    | None ->
        failure source
          "no-unused-export requires reanalyzeReport from rescript-tools \
           reanalyze -dce -json and current compiler artifacts."
    | Some report ->
        Result.map_error
          (fun message ->
            Lint_error.Analysis_errors
              (file_diagnostic source "project-analysis" message, []))
          (Reanalyze_report.check ~project ~report ~source)

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
          if interfaces then interface_findings ~source project else []
        in
        Result.map
          (fun findings -> interface @ findings)
          (if unused then
             unused_findings ~source (Rule_config.options config) project
           else Ok [])

let check ~config ~context ~project ~source document =
  if
    Rule_config.enabled config "no-restricted-modules"
    && (Rule_config.options config).restricted_modules = []
    && Restriction_policy.is_empty (Rule_config.options config).restrictions
  then
    failure source
      "no-restricted-modules requires a nonempty restrictedModules or \
       restrictions policy."
  else
    Result.bind (source_root_policy ~source ~config project) (fun roots ->
        Result.bind
          (match roots with
          | None -> Ok []
          | Some roots ->
              source_root_findings ~source ~context roots document.Parser.tree)
          (fun source_roots ->
            Result.map
              (fun findings ->
                let license =
                  if Rule_config.enabled config "require-license-header" then
                    license_findings ~source
                      (Rule_config.options config)
                      document
                  else []
                in
                Source_range.sort
                  (findings @ license @ source_roots
                  @ reference_findings ~source ~config ~context
                      document.Parser.tree))
              (project_findings ~source ~config project)))
