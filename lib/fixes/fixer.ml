let failure (source : Source.t) detail =
  Error (Lint_error.Fix_error { filename = source.filename; detail })

let check_formatter_findings source findings =
  if
    List.exists
      (fun (finding : Diagnostic.t) -> finding.rule = "blank-lines")
      findings
  then
    failure source
      "The ReScript formatter would undo a spacing fix. File left unchanged."
  else Ok ()

let validate_formatted_source ~lint (source : Source.t) text =
  let formatted = { source with text } in
  Result.bind (Parser.parse_document formatted) (fun _document ->
      Result.bind (lint formatted) (check_formatter_findings source))

let check_formatter_compatibility ~lint ~format source =
  Result.bind (format source) (validate_formatted_source ~lint source)

let validate_fixes ~lint ~format fixed =
  Result.bind (lint fixed) (fun remaining ->
      if List.exists (fun (d : Diagnostic.t) -> d.fixes <> []) remaining then
        failure fixed "Spacing fixes did not converge. File left unchanged."
      else
        Result.map
          (fun () -> (fixed, remaining))
          (check_formatter_compatibility ~lint ~format fixed))

let apply_fixes ~lint ~format (source : Source.t) edits =
  match Text_edit.apply source.text edits with
  | Error (Text_edit.Invalid_range | Text_edit.Overlapping_edits) ->
      failure source "Invalid or conflicting edits. File left unchanged."
  | Ok text -> validate_fixes ~lint ~format { source with text }

let fix_source ?(lint = Linter.lint_source) ?(format = Parser.format) source =
  Result.bind (lint source) (fun diagnostics ->
      match List.concat_map (fun (d : Diagnostic.t) -> d.fixes) diagnostics with
      | [] -> Ok (source, diagnostics)
      | edits -> apply_fixes ~lint ~format source edits)

let write_if_changed (original : Source.t) ((fixed : Source.t), diagnostics) =
  if original.text = fixed.text then Ok diagnostics
  else Result.map (fun () -> diagnostics) (Source.write ~original fixed.text)

let fix_file_with_lint ~lint filename =
  Result.bind (Source.read filename) (fun original ->
      Result.bind (fix_source ~lint original) (write_if_changed original))

let fix_file filename = fix_file_with_lint ~lint:Linter.lint_source filename
