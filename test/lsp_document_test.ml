open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)

let input path text =
  Lsp_document.
    {
      uri = "file:///workspace/" ^ path;
      path = "/workspace/" ^ path;
      language_id = "rescript";
      version = 3;
      text;
    }

let diagnostic =
  Diagnostic.
    {
      rule = "syntax";
      message = "Expected an expression.";
      filename = "/workspace/example.res";
      range =
        {
          start = { line = 1; column = 1; byte_offset = 0 };
          finish = { line = 1; column = 1; byte_offset = 0 };
        };
      fixes = [];
    }

let document_checks =
  match Lsp_document.create (input "example.res" "let answer = 42") with
  | Error error ->
      [ ("creates implementation", Error (Lint_error.render error)) ]
  | Ok document ->
      let updated =
        Lsp_document.update ~version:4 ~text:"Console.log(42)" document
      in
      [
        expect "stores URI"
          (Lsp_document.uri document = "file:///workspace/example.res");
        expect "stores language id"
          (Lsp_document.language_id document = "rescript");
        expect "stores initial version" (Lsp_document.version document = 3);
        expect "derives implementation kind"
          ((Lsp_document.source document).kind = Source.Implementation);
        expect "keeps original immutable"
          ((Lsp_document.source document).text = "let answer = 42");
        expect "indexes document text"
          (Lsp_position.text (Lsp_document.positions document)
          = "let answer = 42");
        expect "accepts newer version"
          (match updated with
          | Ok next ->
              Lsp_document.version next = 4
              && (Lsp_document.source next).text = "Console.log(42)"
          | Error _ -> false);
        expect "rejects duplicate version"
          (Lsp_document.update ~version:3 ~text:"ignored" document
          = Error
              (Lsp_document.Version_not_newer
                 { current_version = 3; received_version = 3 }));
        expect "rejects stale version"
          (Lsp_document.update ~version:2 ~text:"ignored" document
          = Error
              (Lsp_document.Version_not_newer
                 { current_version = 3; received_version = 2 }));
        expect "renders version error"
          (Lsp_document.render_update_error
             (Lsp_document.Version_not_newer
                { current_version = 3; received_version = 2 })
          = "Document version 2 is not newer than current version 3.");
      ]

let checks =
  document_checks
  @ [
      expect "derives interface kind"
        (match Lsp_document.create (input "example.resi" "let answer: int") with
        | Ok document -> (Lsp_document.source document).kind = Source.Interface
        | Error _ -> false);
      expect "rejects unsupported source kind"
        (match Lsp_document.create (input "example.txt" "text") with
        | Error (Lint_error.Unsupported_file "/workspace/example.txt") -> true
        | Ok _ | Error _ -> false);
      expect "extracts parse diagnostics"
        (Lint_error.diagnostics (Lint_error.Parse_errors (diagnostic, []))
        = Some [ diagnostic ]);
      expect "extracts analysis diagnostics"
        (Lint_error.diagnostics (Lint_error.Analysis_errors (diagnostic, []))
        = Some [ diagnostic ]);
      expect "does not invent IO diagnostics"
        (Lint_error.diagnostics
           (Lint_error.Read_error
              { filename = "/workspace/example.res"; detail = "missing" })
        = None);
      expect "does not invent write diagnostics"
        (Lint_error.diagnostics
           (Lint_error.Write_error
              { filename = "/workspace/example.res"; detail = "read-only" })
        = None);
      expect "does not invent fix diagnostics"
        (Lint_error.diagnostics
           (Lint_error.Fix_error
              { filename = "/workspace/example.res"; detail = "overlap" })
        = None);
      expect "does not invent unsupported-file diagnostics"
        (Lint_error.diagnostics
           (Lint_error.Unsupported_file "/workspace/example.txt")
        = None);
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
