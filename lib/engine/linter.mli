val lint_source : Source.t -> (Diagnostic.t list, Lint_error.t) result
val lint_file : string -> (Diagnostic.t list, Lint_error.t) result

val lint_source_with_rules :
  Rule_config.t -> Source.t -> (Diagnostic.t list, Lint_error.t) result

val lint_source_with_loader :
  load_project:
    (config:Rule_config.t ->
    source:Source.t ->
    (Project_files.t option, Lint_error.t) result) ->
  Rule_config.t ->
  Source.t ->
  (Diagnostic.t list, Lint_error.t) result

val lint_file_with_rules :
  Rule_config.t -> string -> (Diagnostic.t list, Lint_error.t) result
