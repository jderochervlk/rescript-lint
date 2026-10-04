let render_error = function
  | Report.Lint error -> Lint_error.render error
  | Command error -> Cli_command.error_message error

let render (report : Report.t) =
  Report.
    {
      stdout = List.map Diagnostic.render report.diagnostics;
      stderr = List.map render_error report.errors;
      outcome = outcome report;
    }
