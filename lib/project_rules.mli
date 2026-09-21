val rule_ids : string list

val check :
  config:Rule_config.t ->
  context:Semantic_model.context ->
  project:Project_files.t option ->
  source:Source.t ->
  Parser.document ->
  (Diagnostic.t list, Lint_error.t) result
