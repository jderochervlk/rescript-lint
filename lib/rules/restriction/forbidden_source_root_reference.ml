let metadata =
  Rule_metadata.
    {
      id = "forbidden-source-root-reference";
      category = Restriction;
      enabled_by_default = false;
    }

open Project_rule_support

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
  Semantic_walk.iter callbacks (Semantic_runtime.initial_scope context) tree;
  match List.rev !unavailable with
  | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
  | [] -> Ok (List.rev !diagnostics)

let source_root_policy ~source ~(options : Project_options.t) project =
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
