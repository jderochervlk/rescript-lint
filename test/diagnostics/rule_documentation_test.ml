open Rescript_linter

let url id =
  "https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/" ^ id
  ^ ".md"

let expect condition message = if condition then Ok () else Error message
let position = Diagnostic.{ line = 1; column = 1; byte_offset = 0 }

let diagnostic rule =
  Diagnostic.
    {
      rule;
      message = "Example finding.";
      filename = "Example.res";
      range = { start = position; finish = position };
      fixes = [];
      help = None;
      symbol = None;
    }

let field key = function
  | `Assoc fields -> List.assoc_opt key fields
  | _ -> None

let catalog_urls () =
  let checks =
    List.map
      (fun (rule : Rule_metadata.t) ->
        let expected = url rule.id in
        let page = Filename.concat "../docs/rules" (rule.id ^ ".md") in
        expect
          (Rule_documentation.url rule.id = Some expected
          && Sys.file_exists page)
          ("Missing or incorrect documentation page for " ^ rule.id))
      Rule_catalog.rules
  in
  match List.find_opt Result.is_error checks with
  | Some (Error message) -> Error message
  | None | Some (Ok ()) ->
      expect
        (Rule_documentation.url "react/rules-of-hooks"
        = Some (url "react/rules-of-hooks"))
        "Namespaced rule URL did not preserve its path"

let unknown_urls () =
  let unknown =
    [
      "syntax";
      "suppression";
      "throws-analysis";
      "source-root-analysis";
      "unknown";
      "correctness/no-unused-export";
      "../README";
      "../../rules/no-unused-export";
      "no-console#fragment";
    ]
  in
  expect
    (List.for_all (fun id -> Rule_documentation.url id = None) unknown)
    "An unregistered or path-traversal rule ID produced a URL"

let json_report report =
  match Json_reporter.render report |> fun output -> output.stdout with
  | [ text ] -> Yojson.Basic.from_string text
  | _ -> `Null

let first_field key value =
  match field key value with Some (`List (first :: _)) -> first | _ -> `Null

let json_diagnostic finding =
  Report.of_results [ Ok [ finding ] ]
  |> json_report |> first_field "diagnostics"

let json_checks () =
  let known = json_diagnostic (diagnostic "no-unused-export") in
  let unknown = json_diagnostic (diagnostic "syntax") in
  let failure =
    Report.of_results
      [ Error (Lint_error.Analysis_errors (diagnostic "no-unused-export", [])) ]
    |> json_report |> first_field "errors" |> first_field "diagnostics"
  in
  expect
    (field "documentationUrl" known = Some (`String (url "no-unused-export"))
    && field "documentationUrl" unknown = Some `Null
    && field "documentationUrl" failure
       = Some (`String (url "no-unused-export")))
    "JSON documentationUrl should be a URL for known rules and null otherwise"

let human_checks () =
  let known = diagnostic "no-unused-export" in
  let unknown = diagnostic "syntax" in
  let report =
    Human_reporter.render (Report.of_results [ Ok [ known; unknown ] ])
  in
  expect
    (report.stdout
     = [
         Diagnostic.render known ^ "\n  Docs: " ^ url known.rule;
         Diagnostic.render unknown;
       ]
    && report.stderr = []
    && report.outcome = Report.Findings)
    "Human output should append Docs only for registered rules"

let human_error_checks () =
  let known = diagnostic "no-unused-export" in
  let namespaced = diagnostic "react/rules-of-hooks" in
  let unknown = diagnostic "syntax" in
  let read_error =
    Lint_error.Read_error { filename = "Missing.res"; detail = "Missing" }
  in
  let report =
    Report.of_results
      [
        Error (Lint_error.Analysis_errors (known, [ namespaced ]));
        Error (Lint_error.Parse_errors (unknown, []));
        Error read_error;
      ]
    |> Human_reporter.render
  in
  expect
    (report.stdout = []
    && report.outcome = Report.Failed
    && report.stderr
       = [
           Diagnostic.render known ^ "\n  Docs: " ^ url known.rule ^ "\n"
           ^ Diagnostic.render namespaced
           ^ "\n  Docs: " ^ url namespaced.rule;
           Diagnostic.render unknown;
           Lint_error.render read_error;
         ])
    "Human errors must link known rules without changing unrelated failures"

let lsp_diagnostics findings =
  let document =
    Lsp_document.create
      {
        uri = "file:///Example.res";
        path = "Example.res";
        language_id = "rescript";
        version = 1;
        text = "x";
      }
  in
  match document with
  | Error _ -> Error "Could not create LSP test document"
  | Ok document ->
      Lsp_diagnostics.of_lint_result ~document ~encoding:Utf8 (Ok findings)
      |> Result.map_error Lsp_diagnostics.render_error

let lsp_checks () =
  match
    lsp_diagnostics [ diagnostic "no-unused-export"; diagnostic "syntax" ]
  with
  | Ok [ known; unknown ] ->
      let known_json = Lsp.Types.Diagnostic.yojson_of_t known in
      let unknown_json = Lsp.Types.Diagnostic.yojson_of_t unknown in
      expect
        (field "codeDescription" known_json
         = Some (`Assoc [ ("href", `String (url "no-unused-export")) ])
        && field "codeDescription" unknown_json = None
        && known.code = Some (`String "no-unused-export")
        && known.message = `String "Example finding.")
        "LSP must use codeDescription without changing code/message"
  | Ok _ | Error _ -> Error "LSP conversion failed"

let run name check =
  match check () with
  | Ok () -> None
  | Error message -> Some (name ^ ": " ^ message)

let () =
  let failures =
    List.filter_map Fun.id
      [
        run "catalog" catalog_urls;
        run "unknown IDs" unknown_urls;
        run "human reporter" human_checks;
        run "human errors" human_error_checks;
        run "JSON reporter" json_checks;
        run "LSP diagnostics" lsp_checks;
      ]
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
