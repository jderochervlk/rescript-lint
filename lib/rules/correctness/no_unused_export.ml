let metadata =
  Rule_metadata.
    {
      id = "no-unused-export";
      category = Correctness;
      enabled_by_default = false;
    }

open Project_rule_support

let unused_findings ~source options project =
  if
    List.mem
      (Project_files.module_name source.Source.filename)
      options.Project_options.entry_modules
  then Ok []
  else
    match options.reanalyze_report with
    | None ->
        failure source
          "no-unused-export requires reanalyzeReport from rescript-tools \
           reanalyze -dce -json and current compiler artifacts."
    | Some report ->
        Result.map_error
          (fun message ->
            Lint_error.Analysis_errors
              (file_diagnostic source "project-analysis" message, []))
          (Reanalyze_report.check ~project ~report ~source)
