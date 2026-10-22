val fix_source :
  ?lint:(Source.t -> (Diagnostic.t list, Lint_error.t) result) ->
  ?format:(Source.t -> (string, Lint_error.t) result) ->
  Source.t ->
  (Source.t * Diagnostic.t list, Lint_error.t) result
(** Validate the original source, then format it in memory before calculating
    and applying lint edits. Re-lint after each batch and fail on no-progress
    edits or after ten batches with fixable findings remaining. Validate the
    converged edits against the formatter. Return the formatted and fixed source
    with diagnostics at its final positions, without writing a file. Formatting
    also applies when no lint fixes are needed. *)

val fix_file : string -> (Diagnostic.t list, Lint_error.t) result

val fix_file_with_lint :
  lint:(Source.t -> (Diagnostic.t list, Lint_error.t) result) ->
  string ->
  (Diagnostic.t list, Lint_error.t) result
