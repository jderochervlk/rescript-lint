let failure (source : Source.t) detail =
  Error (Lint_error.Fix_error { filename = source.filename; detail })

let check_formatter_findings source findings =
  if
    List.exists
      (fun (finding : Diagnostic.t) -> finding.rule = "blank-lines")
      findings
  then
    failure source
      "The ReScript formatter would leave missing blank lines after fixes. \
       File left unchanged."
  else Ok ()

let validate_formatted_source ~lint (source : Source.t) text =
  let formatted = { source with text } in
  Result.bind (Parser.parse_document formatted) (fun _document ->
      Result.bind (lint formatted) (check_formatter_findings source))

let check_formatter_compatibility ~lint ~format source =
  Result.bind (format source) (validate_formatted_source ~lint source)

let diagnostic_edits diagnostics =
  List.concat_map (fun (d : Diagnostic.t) -> d.fixes) diagnostics

let rec validate_fixes ~lint ~format ~passes_left fixed =
  Result.bind (lint fixed) (fun remaining ->
      match diagnostic_edits remaining with
      | [] ->
          Result.map
            (fun () -> (fixed, remaining))
            (check_formatter_compatibility ~lint ~format fixed)
      | _ when passes_left = 0 ->
          failure fixed "Spacing fixes did not converge. File left unchanged."
      | edits -> apply_fixes ~lint ~format ~passes_left fixed edits)

and apply_fixes ~lint ~format ~passes_left (source : Source.t) edits =
  match Text_edit.apply source.text edits with
  | Error (Text_edit.Invalid_range | Text_edit.Overlapping_edits) ->
      failure source "Invalid or conflicting edits. File left unchanged."
  | Ok text when text = source.text ->
      failure source "Spacing fixes did not converge. File left unchanged."
  | Ok text ->
      validate_fixes ~lint ~format ~passes_left:(passes_left - 1)
        { source with text }

let fix_formatted_source ~lint ~format source =
  Result.bind (lint source) (fun diagnostics ->
      match diagnostic_edits diagnostics with
      | [] -> Ok (source, diagnostics)
      | edits ->
          (* Inner separators can make enclosing rows multiline. Re-lint each
             candidate so rule selection and suppressions govern every pass. *)
          apply_fixes ~lint ~format ~passes_left:10 source edits)

let fix_source ?(lint = Linter.lint_source) ?(format = Parser.format) source =
  (* Preserve original-source error locations, then recompute all successful
     diagnostics and edit offsets against the formatted candidate. *)
  Result.bind (lint source) (fun _diagnostics ->
      Result.bind (format source) (fun text ->
          let formatted = { source with Source.text } in
          Result.bind (Parser.parse_document formatted) (fun _document ->
              fix_formatted_source ~lint ~format formatted)))

let write_if_changed (original : Source.t) ((fixed : Source.t), diagnostics) =
  if original.text = fixed.text then Ok diagnostics
  else Result.map (fun () -> diagnostics) (Source.write ~original fixed.text)

let fix_file_with_lint ~lint filename =
  Result.bind (Source.read filename) (fun original ->
      Result.bind (fix_source ~lint original) (write_if_changed original))

let fix_file filename = fix_file_with_lint ~lint:Linter.lint_source filename
