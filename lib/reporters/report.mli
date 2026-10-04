type error = Lint of Lint_error.t | Command of Cli_command.error
type outcome = Clean | Findings | Failed
type t = { diagnostics : Diagnostic.t list; errors : error list }

type response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

val empty_response : response
val exit_code : outcome -> int
val outcome : t -> outcome
val of_results : (Diagnostic.t list, Lint_error.t) result list -> t
val command_error : Cli_command.error -> t
