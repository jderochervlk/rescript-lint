val load :
  config:Rule_config.t ->
  source:Source.t ->
  (Project_files.t option, Lint_error.t) result

val semantic :
  config:Rule_config.t ->
  source:Source.t ->
  Project_files.t option ->
  Semantic_model.context
