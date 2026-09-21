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

let human_results results =
  let response = List.fold_left collect clean results in
  {
    response with
    stdout = List.rev response.stdout;
    stderr = List.rev response.stderr;
  }

let json_response ~diagnostics ~errors =
  let outcome, json_outcome =
    match (errors, diagnostics) with
    | _ :: _, _ -> (Failed, `Failed)
    | [], _ :: _ -> (Findings, `Findings)
    | [], [] -> (Clean, `Clean)
  in
  {
    stdout = [ Json_reporter.render ~outcome:json_outcome ~diagnostics ~errors ];
    stderr = [];
    outcome;
  }

let json_results results =
  let diagnostics, errors =
    List.fold_left
      (fun (diagnostics, errors) -> function
        | Ok found -> (List.rev_append found diagnostics, errors)
        | Error error -> (diagnostics, Json_reporter.Lint error :: errors))
      ([], []) results
  in
  json_response ~diagnostics:(List.rev diagnostics) ~errors:(List.rev errors)

let render_results format results =
  match format with
  | Command.Human -> human_results results
  | Json -> json_results results

let selected_files ~format ~lint rules files =
  match Inputs.files rules files with
  | Ok files -> render_results format (List.map (lint rules) files)
  | Error error -> render_results format [ Error error ]

let run ~lint ~fix arguments =
  let format, command = Command.parse_with_format arguments in
  match command with
  | Ok Help -> { clean with stdout = [ Command.help ] }
  | Ok Version -> { clean with stdout = [ Command.version ] }
  | Ok List_rules -> { clean with stdout = [ Rule_config.listing ] }
  | Ok (Lint { files; rules }) -> selected_files ~format ~lint rules files
  | Ok (Fix { files; rules }) -> selected_files ~format ~lint:fix rules files
  | Ok (Watch { files; fix = false; rules }) ->
      selected_files ~format ~lint rules files
  | Ok (Watch { files; fix = true; rules }) ->
      selected_files ~format ~lint:fix rules files
  | Ok (Language_server _) ->
      {
        clean with
        stderr = [ "Language server mode requires the stdio runtime." ];
        outcome = Failed;
      }
  | Error error when format = Json ->
      json_response ~diagnostics:[] ~errors:[ Json_reporter.Command error ]
  | Error error ->
      { clean with stderr = [ Command.error_message error ]; outcome = Failed }
