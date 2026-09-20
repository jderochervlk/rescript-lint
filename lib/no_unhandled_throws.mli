val check :
  source:Source.t -> Parser.t -> (Diagnostic.t list, Lint_error.t) result
(** Enforces source-local annotations. Unsupported annotated analysis fails
    explicitly. *)
