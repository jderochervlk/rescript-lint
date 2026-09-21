open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)

let document text =
  Lsp_document.create
    {
      uri = "file:///workspace/example.res";
      path = "/workspace/example.res";
      language_id = "rescript";
      version = 4;
      text;
    }

let diagnostic start_offset finish_offset =
  Diagnostic.
    {
      rule = "no-console";
      message = "Do not use Console.log.";
      filename = "/workspace/example.res";
      range =
        {
          start = { line = 1; column = 1; byte_offset = start_offset };
          finish = { line = 1; column = 1; byte_offset = finish_offset };
        };
      fixes = [];
    }

let converted encoding =
  match document "\240\159\152\128Console.log(1)" with
  | Error error -> Error (Lsp_diagnostics.Lint_failed error)
  | Ok document ->
      Lsp_diagnostics.of_lint_result ~document ~encoding
        (Ok [ diagnostic 4 15 ])

let range_is start_character finish_character = function
  | Ok [ diagnostic ] ->
      diagnostic.Lsp.Types.Diagnostic.range.start.character = start_character
      && diagnostic.range.end_.character = finish_character
      && diagnostic.code = Some (`String "no-console")
      && diagnostic.severity = Some Lsp.Types.DiagnosticSeverity.Error
      && diagnostic.source = Some "rescript-lint"
  | Ok _ | Error _ -> false

let parse_error_conversion =
  match document "let =" with
  | Error _ -> false
  | Ok document -> (
      match Linter.lint_source (Lsp_document.source document) with
      | Ok _ -> false
      | Error error ->
          Result.is_ok
            (Lsp_diagnostics.of_lint_result ~document
               ~encoding:Lsp_position.Utf16 (Error error)))

let invalid_range =
  match document "x" with
  | Error _ -> false
  | Ok document -> (
      match
        Lsp_diagnostics.of_lint_result ~document ~encoding:Lsp_position.Utf8
          (Ok [ diagnostic 0 2 ])
      with
      | Error (Lsp_diagnostics.Invalid_diagnostic_range _) -> true
      | Ok _ | Error _ -> false)

let checks =
  [
    expect "decodes file URI"
      (Lsp_uri.local_path
         (Lsp.Types.DocumentUri.of_string
            "file:///workspace/folder%20name/example.res")
      = Ok "/workspace/folder name/example.res");
    expect "rejects non-file URI"
      (Lsp_uri.local_path
         (Lsp.Types.DocumentUri.of_string "untitled:example.res")
      = Error (Lsp_uri.Unsupported_scheme { uri = "untitled:example.res" }));
    expect "renders URI error"
      (Lsp_uri.render_error
         (Lsp_uri.Unsupported_scheme { uri = "untitled:example.res" })
      = "Only file URIs are supported: untitled:example.res");
    expect "converts UTF-8 diagnostic" (range_is 4 15 (converted Utf8));
    expect "converts UTF-16 diagnostic" (range_is 2 13 (converted Utf16));
    expect "converts parse errors" parse_error_conversion;
    expect "rejects invalid diagnostic range" invalid_range;
    expect "preserves non-diagnostic lint failure"
      (match document "x" with
      | Error _ -> false
      | Ok document ->
          let failure = Lint_error.Unsupported_file "example.txt" in
          Lsp_diagnostics.of_lint_result ~document ~encoding:Utf8
            (Error failure)
          = Error (Lsp_diagnostics.Lint_failed failure));
    expect "renders lint failure"
      (Lsp_diagnostics.render_error
         (Lsp_diagnostics.Lint_failed
            (Lint_error.Unsupported_file "example.txt"))
      = "example.txt: Expected a .res or .resi file.");
    expect "renders range failure"
      (Lsp_diagnostics.render_error
         (Lsp_diagnostics.Invalid_diagnostic_range
            {
              diagnostic = diagnostic 0 2;
              reason =
                Lsp_position.Offset_out_of_bounds
                  { byte_offset = 2; text_length = 1 };
            })
      = "/workspace/example.res:1:1: error [no-console] Do not use \
         Console.log.: Cannot convert diagnostic range: Byte offset 2 is \
         outside source text of length 1.");
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
