val fix_source :
  ?lint:(Source.t -> (Diagnostic.t list, Lint_error.t) result) ->
  ?format:(Source.t -> (string, Lint_error.t) result) ->
  Source.t ->
  (Source.t * Diagnostic.t list, Lint_error.t) result

val fix_file : string -> (Diagnostic.t list, Lint_error.t) result
