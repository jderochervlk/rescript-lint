open Rescript_linter
open Project_rules_test_support

let checks root =
  let options = { Project_options.default with root = Some root } in
  let source =
    source (Filename.concat root "src/Main.res") "let value = Api.old(1)"
  in
  [
    ( "missing report is an analysis error",
      match enabled "no-unused-export" options with
      | Error _ -> false
      | Ok config -> (
          match Linter.lint_source_with_rules config source with
          | Error (Lint_error.Analysis_errors _) -> true
          | _ -> false) );
    ( "entry module is exempt",
      check "no-unused-export"
        { options with entry_modules = [ "Main" ] }
        source clean );
    ( "unavailable report is an analysis error",
      match
        enabled "no-unused-export"
          {
            options with
            reanalyze_report = Some (Filename.concat root "missing.json");
          }
      with
      | Error _ -> false
      | Ok config -> (
          match Linter.lint_source_with_rules config source with
          | Error (Lint_error.Analysis_errors (finding, _)) ->
              finding.rule = "project-analysis"
          | _ -> false) );
  ]

let () = Rule_test_runner.run (Rule_test_runner.of_bools (with_project checks))
