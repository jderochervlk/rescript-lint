let rule_ids =
  [
    "no-restricted-modules";
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
      fixes = [];
      range = Source_range.of_location ~source:source.text location;
    }

let file_diagnostic source rule message =
  Diagnostic.
    {
      filename = source.Source.filename;
      rule;
      message;
      fixes = [];
      range = { start = origin; finish = origin };
    }

let failure source message =
  Error
    (Lint_error.Analysis_errors
       (file_diagnostic source "project-analysis" message, []))

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

let restricted restrictions path =
  let name = String.concat "." path in
  List.exists
    (fun prefix ->
      name = prefix || String.starts_with ~prefix:(prefix ^ ".") name)
    restrictions

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
  if Rule_config.enabled config "no-restricted-modules" then
    Option.iter
      (fun path ->
        if restricted (Rule_config.options config).restricted_modules path then
          emit
            (diagnostic source "no-restricted-modules"
               ("This module is restricted: " ^ String.concat "." path ^ ".")
               location))
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
          if Rule_config.enabled config "no-restricted-modules" then
            Option.iter
              (fun path ->
                if
                  restricted (Rule_config.options config).restricted_modules
                    path
                then
                  emit
                    (diagnostic source "no-restricted-modules"
                       ("This module is restricted: " ^ String.concat "." path
                      ^ ".")
                       identifier.Location.loc))
              (Semantic_model.module_identity scope identifier.txt));
    }
  in
  Semantic_walk.iter callbacks (Semantic_model.initial context) tree;
  List.rev !diagnostics

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
  then
    failure source
      "no-restricted-modules requires a nonempty restrictedModules policy."
  else
    Result.map
      (fun findings ->
        let license =
          if Rule_config.enabled config "require-license-header" then
            license_findings ~source (Rule_config.options config) document
          else []
        in
        Source_range.sort
          (findings @ license
          @ reference_findings ~source ~config ~context document.Parser.tree))
      (project_findings ~source ~config project)
