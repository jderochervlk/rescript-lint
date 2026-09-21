type error = Lint of Lint_error.t | Command of Command.error

val render :
  outcome:[ `Clean | `Findings | `Failed ] ->
  diagnostics:Diagnostic.t list ->
  errors:error list ->
  string
(** One compact schema-version-1 JSON record, without a trailing newline. *)
