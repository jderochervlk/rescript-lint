open Rescript_linter

let write path text =
  Out_channel.with_open_bin path (fun channel -> output_string channel text)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  let root = Filename.temp_file "lint-index-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") "{}";
  let source =
    Source.
      {
        filename = path "src/Main.res";
        text = "let value = Provider.old";
        kind = Implementation;
      }
  in
  write source.filename source.text;
  write (path "src/Provider.resi") "@deprecated(\"Use modern\") let old: int";
  let calls = ref 0 in
  let parse source =
    incr calls;
    Parser.parse source
  in
  let cache = ref (Project_index.create ~parse) in
  let lint_calls = ref 0 in
  let parse_overlay source =
    incr lint_calls;
    Parser.parse_overlay source
  in
  let load_project ~config ~overlay =
    let next, result = Project_context.load_cached !cache ~config ~overlay in
    cache := next;
    result
  in
  let options = { Project_options.default with root = Some root } in
  match
    Rule_config.set
      (Rule_config.with_options options Rule_config.default)
      ~id:"no-deprecated-api" ~enabled:true
  with
  | Error _ -> [ ("configuration valid", false) ]
  | Ok config ->
      let lint source =
        Linter.lint_source_with_loader ~parse:parse_overlay ~load_project config
          source
      in
      let first = lint source in
      let uncached = Linter.lint_source_with_rules config source in
      let first_calls = !calls in
      let again = lint source in
      let reused = !calls = first_calls in
      let once_per_lint = first_calls = 1 && !lint_calls = 2 in
      let suppressed_source =
        {
          source with
          text =
            "// rescript-lint-disable-next-line no-deprecated-api\n\
             let value = Provider.old";
        }
      in
      let suppressed = lint suppressed_source in
      let suppressed_uncached =
        Linter.lint_source_with_rules config suppressed_source
      in
      let invalid_source = { source with text = "let =" } in
      let before_invalid = !calls in
      let invalid_overlay = lint invalid_source in
      let invalid_overlay_uncached =
        Linter.lint_source_with_rules config invalid_source
      in
      let after_invalid = lint source in
      let overlay_retained = !calls = before_invalid in
      write (path "src/Provider.resi") "let old: int";
      let updated = lint source in
      write (path "src/Provider.resi") "let =";
      let invalid = lint source in
      let invalid_uncached = Linter.lint_source_with_rules config source in
      write (path "src/Provider.resi") "let old: int";
      let recovered = lint source in
      let _, standalone =
        Project_context.load_cached !cache ~config:Rule_config.default
          ~overlay:(Result.get_ok (Parser.parse_overlay source))
      in
      [
        ("cached and uncached diagnostics match", first = uncached);
        ( "cached lint retains findings",
          first = again && Result.is_ok first && first <> Ok [] );
        ("unchanged provider parse reused", reused);
        ("one overlay parse across lint and project boundaries", once_per_lint);
        ( "overlay document preserves suppression comments",
          suppressed = Ok [] && suppressed = suppressed_uncached );
        ( "invalid overlay fails before project loading and retains disk cache",
          Result.is_error invalid_overlay
          && invalid_overlay = invalid_overlay_uncached
          && after_invalid = first && overlay_retained );
        ("cached and uncached project errors match", invalid = invalid_uncached);
        ("changed interface recomputes diagnostics", updated = Ok []);
        ("invalid provider never returns stale success", Result.is_error invalid);
        ("fixed provider recovers", recovered = Ok []);
        ("no project remains standalone", standalone = Ok None);
      ]

let provenance_checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  Unix.mkdir (path "src/internal") 0o700;
  write (path "rescript.json") {|{"sources":[{"dir":"src","subdirs":true}]}|};
  write (path "src/internal/Secret.res") "let value = 1";
  write (path "src/Main.res") "let saved = 0";
  let calls = ref 0 in
  let parse source =
    incr calls;
    Parser.parse source
  in
  let cache = ref (Project_index.create ~parse) in
  let load_project ~config ~overlay =
    let next, result = Project_context.load_cached !cache ~config ~overlay in
    cache := next;
    result
  in
  let options =
    {
      Project_options.default with
      root = Some root;
      forbidden_source_roots = [ path "src/internal" ];
    }
  in
  match
    Rule_config.set
      (Rule_config.with_options options Rule_config.default)
      ~id:"forbidden-source-root-reference" ~enabled:true
  with
  | Error _ -> [ ("provenance configuration valid", false) ]
  | Ok config ->
      let lint text =
        Linter.lint_source_with_loader ~load_project config
          Source.{ filename = path "src/Main.res"; text; kind = Implementation }
      in
      let forbidden = lint "let x = Secret.value" in
      let first_calls = !calls in
      let repeated = lint "let x = Secret.value" in
      let reused = !calls = first_calls in
      let unsaved_clean = lint "let x = 1" in
      write (path "src/internal/Secret.res") "let value = 2";
      let changed_provider = lint "let x = Secret.value" in
      [
        ( "cached provenance finding",
          Result.is_ok forbidden && forbidden <> Ok [] );
        ("repeated provenance finding", forbidden = repeated);
        ("unchanged provenance needs no project parses", reused);
        ("unsaved consumer overlay clears finding", unsaved_clean = Ok []);
        ( "changed provider invalidates provenance cache",
          Result.is_ok changed_provider && changed_provider <> Ok [] );
      ]

let client_checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") "{}";
  write (path "src/Main.res") "let saved = 0";
  write (path "src/Other.res") "let saved = 0";
  write (path "src/Provider.resi") "@deprecated(\"Use modern\") let old: int";
  let config =
    Rule_config.with_options
      { Project_options.default with root = Some root }
      Rule_config.default
    |> fun config ->
    Result.get_ok (Rule_config.set config ~id:"no-deprecated-api" ~enabled:true)
  in
  let cache = ref Project_index.empty in
  let load_project ~config ~overlay =
    let next, result = Project_context.load_cached !cache ~config ~overlay in
    cache := next;
    result
  in
  let lint = Linter.lint_source_with_loader ~load_project config in
  let source =
    Source.
      {
        filename = path "src/Main.res";
        kind = Implementation;
        text = "Provider.old->consume\ndone()\n";
      }
  in
  let fixed = Fixer.fix_source ~lint source in
  let fixed_uncached =
    Fixer.fix_source ~lint:(Linter.lint_source_with_rules config) source
  in
  let fixes_overlay =
    match fixed with
    | Ok (fixed, findings) ->
        fixed.text = "Provider.old->consume\n\ndone()\n"
        && List.exists
             (fun (d : Diagnostic.t) -> d.rule = "no-deprecated-api")
             findings
    | Error _ -> false
  in
  let dependencies = Lsp_server.{ lint } in
  let handle = Lsp_server.handle ~dependencies in
  let params =
    Lsp.Types.InitializeParams.create
      ~capabilities:(Lsp.Types.ClientCapabilities.create ())
      ()
  in
  let initialize =
    Jsonrpc.Packet.Request
      (Lsp.Client_request.to_jsonrpc_request
         (Lsp.Client_request.Initialize params) ~id:(`Int 1))
  in
  let state, _ = handle Lsp_server.initial initialize in
  let open_buffer state filename text version =
    let uri = Lsp.Types.DocumentUri.of_string ("file://" ^ filename) in
    let item =
      Lsp.Types.TextDocumentItem.create ~languageId:"rescript" ~text ~uri
        ~version
    in
    let params =
      Lsp.Types.DidOpenTextDocumentParams.create ~textDocument:item
    in
    handle state
      (Jsonrpc.Packet.Notification
         (Lsp.Client_notification.to_jsonrpc
            (Lsp.Client_notification.TextDocumentDidOpen params)))
  in
  let change_buffer state text version =
    let uri = Lsp.Types.DocumentUri.of_string ("file://" ^ source.filename) in
    let document =
      Lsp.Types.VersionedTextDocumentIdentifier.create ~uri ~version
    in
    let change = Lsp.Types.TextDocumentContentChangeEvent.create ~text () in
    let params =
      Lsp.Types.DidChangeTextDocumentParams.create ~contentChanges:[ change ]
        ~textDocument:document
    in
    handle state
      (Jsonrpc.Packet.Notification
         (Lsp.Client_notification.to_jsonrpc
            (Lsp.Client_notification.TextDocumentDidChange params)))
  in
  let diagnostic_codes effects =
    List.find_map
      (function
        | Lsp_server.Send (Jsonrpc.Packet.Notification notification) -> (
            match Lsp.Server_notification.of_jsonrpc notification with
            | Ok (Lsp.Server_notification.PublishDiagnostics params) ->
                Some
                  (List.map
                     (fun (d : Lsp.Types.Diagnostic.t) -> d.code)
                     params.diagnostics)
            | _ -> None)
        | _ -> None)
      effects
  in
  let state, findings =
    open_buffer state source.filename "let x = Provider.old" 1
  in
  let state, invalid = change_buffer state "let =" 2 in
  let _, other =
    open_buffer state (path "src/Other.res") "let x = Provider.old" 1
  in
  write (path "src/Provider.resi") "let old: int";
  let _, updated = change_buffer state "let x = Provider.old" 3 in
  [
    ( "fixer validates changed project overlays",
      fixes_overlay && fixed = fixed_uncached );
    ( "LSP unsaved project buffer gets semantic finding",
      diagnostic_codes findings = Some [ Some (`String "no-deprecated-api") ] );
    ( "LSP invalid buffer publishes syntax errors",
      Option.fold ~none:false
        ~some:(List.exists (( = ) (Some (`String "syntax"))))
        (diagnostic_codes invalid) );
    ( "LSP invalid buffer leaves other document analysis intact",
      diagnostic_codes other = diagnostic_codes findings );
    ( "LSP project dependency content changes invalidate findings",
      diagnostic_codes updated = Some [] );
  ]

let lint_cached config cache source =
  match Parser.parse_overlay source with
  | Error error -> (cache, Error error)
  | Ok overlay ->
      let cache, project = Project_context.load_cached cache ~config ~overlay in
      let result =
        Linter.lint_source_with_loader
          ~parse:(fun _ -> Ok overlay)
          ~load_project:(fun ~config:_ ~overlay:_ -> project)
          config source
      in
      (cache, result)

let throws_preparation_checks root =
  let path name = Filename.concat root name in
  Unix.mkdir (path "src") 0o700;
  write (path "rescript.json") {|{"sources":["src"]}|};
  let contract = "exception Missing\n@throws(Missing) let read: unit => int" in
  write (path "src/Api.resi") contract;
  let caller =
    Source.
      {
        filename = path "src/Main.res";
        text = "Api.read()";
        kind = Implementation;
      }
  in
  write caller.filename caller.text;
  let config =
    List.fold_left
      (fun result (rule : Rule_config.rule) ->
        Result.bind result (fun config ->
            Rule_config.set config ~id:rule.id
              ~enabled:(rule.id = "no-unhandled-throws")))
      (Ok
         (Rule_config.with_options
            { Project_options.default with root = Some root }
            Rule_config.default))
      Rule_config.rules
  in
  match config with
  | Error _ -> [ ("throws preparation configuration valid", false) ]
  | Ok config ->
      let lint = lint_cached config in
      let cache, first = lint Project_index.empty caller in
      let overlay cache text =
        lint cache
          Source.{ filename = path "src/Api.resi"; text; kind = Interface }
      in
      let cache, clean_overlay = overlay cache "let read: unit => int" in
      let cache, after_clean = lint cache caller in
      let cache, invalid_overlay =
        overlay cache "@throws(Unknown) let read: unit => int"
      in
      let cache, after_invalid = lint cache caller in
      write (path "src/Api.resi") "let read: unit => int";
      let cache, changed = lint cache caller in
      write (path "src/Api.resi") contract;
      let _, recovered = lint cache caller in
      [
        ( "throws preparation initially finds contract",
          Result.is_ok first && first <> Ok [] );
        ("interface overlay rebuilds throws preparation", clean_overlay = Ok []);
        ("clean overlay cannot leak into disk preparation", after_clean = first);
        ( "invalid overlay fails instead of reusing old preparation",
          Result.is_error invalid_overlay );
        ("invalid overlay cannot poison disk preparation", after_invalid = first);
        ("changed contract rebuilds throws preparation", changed = Ok []);
        ("restored contract rebuilds throws preparation", recovered = first);
      ]

let () =
  let failed =
    temporary checks
    @ temporary provenance_checks
    @ temporary client_checks
    @ temporary throws_preparation_checks
    |> List.filter_map (fun (name, passed) ->
        if passed then None else Some name)
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
