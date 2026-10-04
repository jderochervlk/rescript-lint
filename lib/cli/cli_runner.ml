type outcome = Report.outcome = Clean | Findings | Failed

type response = Report.response = {
  stdout : string list;
  stderr : string list;
  outcome : outcome;
}

type file_check =
  Rule_config.t -> string -> (Diagnostic.t list, Lint_error.t) result

let exit_code = Report.exit_code
let empty_response = Report.empty_response

let render_report = function
  | Cli_command.Human -> Human_reporter.render
  | Json -> Json_reporter.render

let run_files ~format ~check rules files =
  let results =
    match Input_files.resolve rules files with
    | Ok files -> List.map (check rules) files
    | Error error -> [ Error error ]
  in
  render_report format (Report.of_results results)

let execute ~lint ~fix ~format = function
  | Cli_command.Help -> { empty_response with stdout = [ Cli_command.help ] }
  | Version -> { empty_response with stdout = [ Cli_command.version ] }
  | List_rules -> { empty_response with stdout = [ Rule_config.listing ] }
  | Inspect_config { filename; rules } ->
      let output =
        match format with
        | Cli_command.Human -> Config_inspector.render ~filename rules
        | Json ->
            Yojson.Basic.to_string (Config_inspector.describe ~filename rules)
      in
      { empty_response with stdout = [ output ] }
  | Lint { files; rules } -> run_files ~format ~check:lint rules files
  | Fix { files; rules } -> run_files ~format ~check:fix rules files
  | Watch { files; fix = apply_fixes; rules } ->
      let check = if apply_fixes then fix else lint in
      run_files ~format ~check rules files
  | Language_server _ ->
      {
        empty_response with
        stderr = [ "Language server mode requires the stdio runtime." ];
        outcome = Failed;
      }

let run ~lint ~fix arguments =
  let format, command = Cli_command.parse_with_format arguments in
  match command with
  | Ok command -> execute ~lint ~fix ~format command
  | Error error -> render_report format (Report.command_error error)
