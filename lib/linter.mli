val lint_source : Source.t -> (Diagnostic.t list, Lint_error.t) result
val lint_file : string -> (Diagnostic.t list, Lint_error.t) result
