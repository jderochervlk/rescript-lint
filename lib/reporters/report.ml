type error = Lint of Lint_error.t | Command of Cli_command.error
type outcome = Clean | Findings | Failed
type t = { diagnostics : Diagnostic.t list; errors : error list }

type response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

let empty_response = { stdout = []; stderr = []; outcome = Clean }
let exit_code = function Clean -> 0 | Findings -> 1 | Failed -> 2

let outcome report =
  match (report.errors, report.diagnostics) with
  | _ :: _, _ -> Failed
  | [], _ :: _ -> Findings
  | [], [] -> Clean

let of_results results =
  let diagnostics, errors =
    List.fold_left
      (fun (diagnostics, errors) -> function
        | Ok found -> (List.rev_append found diagnostics, errors)
        | Error error -> (diagnostics, Lint error :: errors))
      ([], []) results
  in
  { diagnostics = List.rev diagnostics; errors = List.rev errors }

let command_error error = { diagnostics = []; errors = [ Command error ] }
