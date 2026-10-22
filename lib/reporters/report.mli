type error = Lint of Lint_error.t | Command of Cli_command.error
type outcome = Clean | Findings | Failed

type t = {
  diagnostics : Diagnostic.t list;
  errors : error list;
  checked_file_count : int;
  warnings : string list;
}

type response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

val empty_response : response
val exit_code : outcome -> int
val outcome : t -> outcome

val of_results : (Diagnostic.t list, Lint_error.t) result list -> t
(** Counts successful checks, including checks with findings, but not errors. *)

val empty_project : root:string -> t
(** A successful zero-file discovery with actionable selection guidance. *)

val command_error : Cli_command.error -> t
