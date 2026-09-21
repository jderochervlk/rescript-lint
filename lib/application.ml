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

let selected_files ~lint rules files =
  match Inputs.files rules files with
  | Ok files -> lint_files ~lint:(lint rules) files
  | Error error -> collect clean (Error error)

let run ~lint ~fix arguments =
  match Command.parse arguments with
  | Ok Help -> { clean with stdout = [ Command.help ] }
  | Ok Version -> { clean with stdout = [ Command.version ] }
  | Ok List_rules -> { clean with stdout = [ Rule_config.listing ] }
  | Ok (Lint { files; rules }) -> selected_files ~lint rules files
  | Ok (Fix { files; rules }) -> selected_files ~lint:fix rules files
  | Ok (Watch { files; fix = false; rules }) -> selected_files ~lint rules files
  | Ok (Watch { files; fix = true; rules }) ->
      selected_files ~lint:fix rules files
  | Ok (Language_server _) ->
      {
        clean with
        stderr = [ "Language server mode requires the stdio runtime." ];
        outcome = Failed;
      }
  | Error error ->
      { clean with stderr = [ Command.error_message error ]; outcome = Failed }
