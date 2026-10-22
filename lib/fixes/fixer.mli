val fix_source :
  ?lint:(Source.t -> (Diagnostic.t list, Lint_error.t) result) ->
  ?format:(Source.t -> (string, Lint_error.t) result) ->
  Source.t ->
  (Source.t * Diagnostic.t list, Lint_error.t) result
(** Apply diagnostic edits in memory, re-linting after each batch so newly
    multiline enclosing rows can receive their own separators. Fail on
    no-progress edits or after ten batches with fixable findings remaining.
    Validate the converged candidate against the formatter; return the minimally
    edited source rather than formatter output, without writing a file. *)

val fix_file : string -> (Diagnostic.t list, Lint_error.t) result

val fix_file_with_lint :
  lint:(Source.t -> (Diagnostic.t list, Lint_error.t) result) ->
  string ->
  (Diagnostic.t list, Lint_error.t) result
