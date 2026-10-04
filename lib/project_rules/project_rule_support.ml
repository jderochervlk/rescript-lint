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
