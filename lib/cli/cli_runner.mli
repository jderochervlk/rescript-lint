type outcome = Report.outcome = Clean | Findings | Failed

type response = Report.response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

type file_check =
  Rule_config.t -> string -> (Diagnostic.t list, Lint_error.t) result

val execute :
  lint:file_check ->
  fix:file_check ->
  Cli_command.format * (Cli_command.t, Cli_command.error) result ->
  response
(** Execute an already-decoded command without rereading its configuration.
    Watch callers must decode again for each rerun to reload configuration. *)

val run : lint:file_check -> fix:file_check -> string list -> response
(** JSON mode emits one complete schema-version-1 record in [stdout] and leaves
    [stderr] empty. Human output and exit-code semantics are unchanged. *)

val exit_code : outcome -> int
