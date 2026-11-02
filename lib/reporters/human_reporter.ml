let render_diagnostic (diagnostic : Diagnostic.t) =
  let documentation =
    Option.fold ~none:""
      ~some:(fun url -> "\n  Docs: " ^ url)
      (Rule_documentation.url diagnostic.rule)
  in
  Diagnostic.render diagnostic ^ documentation

let render_lint_error error =
  match Lint_error.diagnostics error with
  | None -> Lint_error.render error
  | Some diagnostics ->
      String.concat "\n" (List.map render_diagnostic diagnostics)

let render_error = function
  | Report.Lint error -> render_lint_error error
  | Command error -> Cli_command.error_message error

let render (report : Report.t) =
  Report.
    {
      stdout = List.map render_diagnostic report.diagnostics;
      stderr =
        List.map render_error report.errors
        @ List.map (fun text -> "Warning: " ^ text) report.warnings;
      outcome = outcome report;
    }
