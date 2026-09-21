open Rescript_linter

let expect name passed = (name, if passed then Ok () else Error name)
let uri = "file:///workspace/example.res"

let document =
  Lsp_document.create
    {
      uri;
      path = "/workspace/example.res";
      language_id = "rescript";
      version = 1;
      text = "let answer = 42";
    }

let checks =
  match document with
  | Error error -> [ ("creates fixture", Error (Lint_error.render error)) ]
  | Ok document ->
      let open Lsp_document_store in
      let opened = open_document document empty in
      let store = Result.value ~default:empty opened in
      let changed = change ~uri ~version:2 ~text:"Console.log(42)" store in
      let changed_document, changed_store =
        Result.value ~default:(document, empty) changed
      in
      let stale_reason =
        Lsp_document.Version_not_newer
          { current_version = 1; received_version = 1 }
      in
      [
        expect "starts empty" (count empty = 0);
        expect "opens document" (Result.is_ok opened && count store = 1);
        expect "finds document" (find ~uri store = Some document);
        expect "keeps prior store immutable" (find ~uri empty = None);
        expect "rejects duplicate open"
          (open_document document store = Error (Already_open { uri }));
        expect "changes document"
          (Lsp_document.version changed_document = 2
          && (Lsp_document.source changed_document).text = "Console.log(42)"
          && find ~uri changed_store = Some changed_document);
        expect "rejects change for missing document"
          (change ~uri ~version:2 ~text:"text" empty = Error (Not_open { uri }));
        expect "rejects stale change"
          (change ~uri ~version:1 ~text:"text" store
          = Error (Update_rejected { uri; reason = stale_reason }));
        expect "closes document"
          (match close ~uri store with
          | Ok (closed, next) -> closed = document && count next = 0
          | Error _ -> false);
        expect "rejects close for missing document"
          (close ~uri empty = Error (Not_open { uri }));
        expect "renders duplicate-open error"
          (render_error (Already_open { uri })
          = "Document is already open: " ^ uri);
        expect "renders missing-document error"
          (render_error (Not_open { uri }) = "Document is not open: " ^ uri);
        expect "renders rejected-update error"
          (render_error (Update_rejected { uri; reason = stale_reason })
          = "Cannot update " ^ uri
            ^ ": Document version 1 is not newer than current version 1.");
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
