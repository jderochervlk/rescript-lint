type error =
  | Lint_failed of Lint_error.t
  | Invalid_diagnostic_range of {
      diagnostic : Diagnostic.t;
      reason : Lsp_position.error;
    }

val of_lint_result :
  document:Lsp_document.t ->
  encoding:Lsp_position.encoding ->
  (Diagnostic.t list, Lint_error.t) result ->
  (Lsp.Types.Diagnostic.t list, error) result

val render_error : error -> string
