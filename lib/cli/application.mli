type outcome = Clean | Findings | Failed

type response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

type lint = string -> (Diagnostic.t list, Lint_error.t) result

val run :
  lint:(Rule_config.t -> lint) ->
  fix:(Rule_config.t -> lint) ->
  string list ->
  response
(** JSON mode emits one complete schema-version-1 record in [stdout] and leaves
    [stderr] empty. Human output and exit-code semantics are unchanged. *)

val exit_code : outcome -> int
