val lint_source : Source.t -> (Diagnostic.t list, Lint_error.t) result
val lint_file : string -> (Diagnostic.t list, Lint_error.t) result

val lint_source_with_rules :
  Rule_config.t -> Source.t -> (Diagnostic.t list, Lint_error.t) result

val lint_source_with_loader :
  ?parse:(Source.t -> (Parser.parsed_overlay, Lint_error.t) result) ->
  load_project:
    (config:Rule_config.t ->
    overlay:Parser.parsed_overlay ->
    (Project_files.t option, Lint_error.t) result) ->
  Rule_config.t ->
  Source.t ->
  (Diagnostic.t list, Lint_error.t) result

val lint_file_with_rules :
  Rule_config.t -> string -> (Diagnostic.t list, Lint_error.t) result
