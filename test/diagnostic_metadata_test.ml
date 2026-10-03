open Rescript_linter

let position = Diagnostic.{ line = 1; column = 1; byte_offset = 0 }

let base =
  Diagnostic.
    {
      rule = "no-restricted-modules";
      message = "Restricted reference.";
      filename = "/workspace/Policy.res";
      range = { start = position; finish = position };
      fixes = [];
      help = None;
      symbol = None;
    }

let field key = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt key fields)
  | _ -> `Null

let json finding =
  let report =
    Json_reporter.render ~outcome:`Findings ~diagnostics:[ finding ] ~errors:[]
    |> Yojson.Basic.from_string
  in
  match field "diagnostics" report with
  | `List [ finding ] -> finding
  | _ -> `Null

let lsp finding =
  Result.bind
    (Lsp_document.create
       {
         uri = "file:///workspace/Policy.res";
         path = "/workspace/Policy.res";
         language_id = "rescript";
         version = 1;
         text = "";
       }
    |> Result.map_error Lint_error.render)
    (fun document ->
      Lsp_diagnostics.of_lint_result ~document ~encoding:Utf8 (Ok [ finding ])
      |> Result.map_error Lsp_diagnostics.render_error)

let cases =
  [
    (base, "Restricted reference.", `Null, `Null);
    ( { base with help = Some { message = "Use the public API."; url = None } },
      "Restricted reference.\n  Help: Use the public API.",
      `Assoc [ ("message", `String "Use the public API."); ("url", `Null) ],
      `Null );
    ( {
        base with
        help =
          Some
            {
              message = "Use the public API.";
              url = Some "https://example.com/policy";
            };
        symbol = Some { kind = Value; path = "Api.value" };
      },
      "Restricted reference.\n\
      \  Resolved value: Api.value\n\
      \  Help: Use the public API. (https://example.com/policy)",
      `Assoc
        [
          ("message", `String "Use the public API.");
          ("url", `String "https://example.com/policy");
        ],
      `Assoc [ ("kind", `String "value"); ("path", `String "Api.value") ] );
    ( { base with symbol = Some { kind = Module; path = "Api" } },
      "Restricted reference.\n  Resolved module: Api",
      `Null,
      `Assoc [ ("kind", `String "module"); ("path", `String "Api") ] );
    ( { base with symbol = Some { kind = Type; path = "Api.t" } },
      "Restricted reference.\n  Resolved type: Api.t",
      `Null,
      `Assoc [ ("kind", `String "type"); ("path", `String "Api.t") ] );
  ]

let check (finding, detail, help, symbol) =
  let json = json finding in
  let human = Diagnostic.render finding in
  let expected =
    "/workspace/Policy.res:1:1: error [no-restricted-modules] " ^ detail
  in
  if
    human <> expected
    || field "help" json <> help
    || field "symbol" json <> symbol
  then Error "Text or JSON metadata differs"
  else
    Result.bind (lsp finding) (function
      | [ converted ] ->
          let json = Lsp.Types.Diagnostic.yojson_of_t converted in
          let expected =
            Yojson.Safe.from_string
              (Yojson.Basic.to_string
                 (`Assoc [ ("help", help); ("symbol", symbol) ]))
          in
          let data =
            match json with
            | `Assoc fields -> List.assoc_opt "data" fields
            | _ -> None
          in
          if converted.message <> `String detail then
            Error "LSP message differs"
          else if finding.help = None && finding.symbol = None then
            if converted.data = None then Ok ()
            else Error "Empty LSP metadata added"
          else if data = Some expected then Ok ()
          else Error "LSP structured metadata differs"
      | _ -> Error "Missing LSP finding")

let () =
  let failures =
    List.filter_map
      (fun case ->
        match check case with Ok () -> None | Error detail -> Some detail)
      cases
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
