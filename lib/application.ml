type outcome = Clean | Findings | Failed

type response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

type lint = string -> (Diagnostic.t list, Lint_error.t) result

let exit_code = function Clean -> 0 | Findings -> 1 | Failed -> 2
let clean = { stdout = []; stderr = []; outcome = Clean }

let add_diagnostics response diagnostics =
  let outcome =
    match (response.outcome, diagnostics) with
    | Failed, _ -> Failed
    | outcome, [] -> outcome
    | _, _ :: _ -> Findings
  in
  {
    response with
    stdout =
      List.rev_append (List.map Diagnostic.render diagnostics) response.stdout;
    outcome;
  }

let collect response = function
  | Ok diagnostics -> add_diagnostics response diagnostics
  | Error failure ->
      {
        response with
        stderr = Lint_error.render failure :: response.stderr;
        outcome = Failed;
      }

let lint_files ~lint files =
  let response =
    List.fold_left
      (fun response file -> collect response (lint file))
      clean files
  in
  {
    response with
    stdout = List.rev response.stdout;
    stderr = List.rev response.stderr;
  }

let run ~lint arguments =
  match Command.parse arguments with
  | Ok Help -> { clean with stdout = [ Command.help ] }
  | Ok Version -> { clean with stdout = [ Command.version ] }
  | Ok (Lint files) -> lint_files ~lint files
  | Error error ->
      { clean with stderr = [ Command.error_message error ]; outcome = Failed }
