let failure (source : Source.t) detail =
  Error (Lint_error.Fix_error { filename = source.filename; detail })

let formatter_stable ~format (source : Source.t) =
  Result.bind (format source) (fun text ->
      let formatted = { source with text } in
      Result.bind (Parser.parse_document formatted) (fun document ->
          if Blank_lines.check ~source:formatted document = [] then Ok ()
          else
            failure source
              "The ReScript formatter would undo a spacing fix. File left \
               unchanged."))

let validate_fixed ~lint ~format fixed =
  Result.bind (lint fixed) (fun remaining ->
      if List.exists (fun (d : Diagnostic.t) -> d.fixes <> []) remaining then
        failure fixed "Spacing fixes did not converge. File left unchanged."
      else
        Result.map
          (fun () -> (fixed, remaining))
          (formatter_stable ~format fixed))

let fix_source ?(lint = Linter.lint_source) ?(format = Parser.format) source =
  Result.bind (lint source) (fun diagnostics ->
      let edits =
        List.concat_map (fun (d : Diagnostic.t) -> d.fixes) diagnostics
      in
      match edits with
      | [] -> Ok (source, diagnostics)
      | _ -> (
          match Text_edit.apply source.Source.text edits with
          | Error _ ->
              failure source
                "Invalid or conflicting edits. File left unchanged."
          | Ok text ->
              let fixed = { source with text } in
              validate_fixed ~lint ~format fixed))

let fix_file filename =
  Result.bind (Source.read filename) (fun original ->
      Result.bind (fix_source original) (fun (fixed, diagnostics) ->
          if original.text = fixed.text then Ok diagnostics
          else
            Result.map
              (fun () -> diagnostics)
              (Source.write ~original fixed.text)))
