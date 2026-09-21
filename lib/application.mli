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

val exit_code : outcome -> int
