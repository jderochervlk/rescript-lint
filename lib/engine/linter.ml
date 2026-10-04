let ( let* ) = Result.bind

let filter_enabled config diagnostics =
  List.filter
    (fun (diagnostic : Diagnostic.t) ->
      Rule_config.enabled config diagnostic.rule)
    diagnostics

let lint_source_with_loader ~load_project config (source : Source.t) =
  let config = Rule_config.for_file ~filename:source.filename config in
  let* document = Parser.parse_document source in
  let* project = load_project ~config ~source in
  let* context =
    Project_context.semantic_with_dependencies ~config ~source project
  in
  let* diagnostics =
    Rule_checks.check ~config ~context ~project ~source document
  in
  let known_rules =
    List.map (fun rule -> rule.Rule_config.id) Rule_config.rules
  in
  Ok
    (filter_enabled config diagnostics
    |> Suppressions.apply ~known_rules ~source document
    |> Source_range.sort)

let lint_source_with_rules config source =
  lint_source_with_loader ~load_project:Project_context.load config source

let lint_source source = lint_source_with_rules Rule_config.default source

let lint_file_with_rules rules filename =
  Result.bind (Source.read filename) (lint_source_with_rules rules)

let lint_file filename = Result.bind (Source.read filename) lint_source
