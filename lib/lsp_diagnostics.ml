type error =
  | Lint_failed of Lint_error.t
  | Invalid_diagnostic_range of {
      diagnostic : Diagnostic.t;
      reason : Lsp_position.error;
    }

let diagnostics = function
  | Ok diagnostics -> Ok diagnostics
  | Error error -> (
      match Lint_error.diagnostics error with
      | Some diagnostics -> Ok diagnostics
      | None -> Error (Lint_failed error))

let lsp_position (position : Lsp_position.position) =
  Lsp.Types.Position.create ~line:position.line ~character:position.character

let lsp_range (range : Lsp_position.range) =
  Lsp.Types.Range.create ~start:(lsp_position range.start)
    ~end_:(lsp_position range.finish)

let metadata (diagnostic : Diagnostic.t) =
  match (diagnostic.help, diagnostic.symbol) with
  | None, None -> None
  | help, symbol ->
      Some
        (`Assoc
           [
             ( "help",
               Option.fold ~none:`Null
                 ~some:(fun (help : Diagnostic.help) ->
                   `Assoc
                     [
                       ("message", `String help.message);
                       ( "url",
                         Option.fold ~none:`Null
                           ~some:(fun url -> `String url)
                           help.url );
                     ])
                 help );
             ( "symbol",
               Option.fold ~none:`Null
                 ~some:(fun (symbol : Diagnostic.symbol) ->
                   `Assoc
                     [
                       ("kind", `String (Diagnostic.kind_name symbol.kind));
                       ("path", `String symbol.path);
                     ])
                 symbol );
           ])

let convert document encoding (diagnostic : Diagnostic.t) =
  let positions = Lsp_document.positions document in
  match
    Lsp_position.range positions ~encoding
      ~start_offset:diagnostic.range.start.byte_offset
      ~finish_offset:diagnostic.range.finish.byte_offset
  with
  | Error reason -> Error (Invalid_diagnostic_range { diagnostic; reason })
  | Ok range ->
      Ok
        (Lsp.Types.Diagnostic.create ~code:(`String diagnostic.rule)
           ?data:(metadata diagnostic)
           ~message:(`String (Diagnostic.detail diagnostic))
           ~range:(lsp_range range) ~severity:Lsp.Types.DiagnosticSeverity.Error
           ~source:"rescript-lint" ())

let of_lint_result ~document ~encoding result =
  Result.bind (diagnostics result) (fun diagnostics ->
      List.fold_left
        (fun converted diagnostic ->
          Result.bind converted (fun reversed ->
              Result.map
                (fun item -> item :: reversed)
                (convert document encoding diagnostic)))
        (Ok []) diagnostics
      |> Result.map List.rev)

let render_error = function
  | Lint_failed error -> Lint_error.render error
  | Invalid_diagnostic_range { diagnostic; reason } ->
      Printf.sprintf "%s: Cannot convert diagnostic range: %s"
        (Diagnostic.render diagnostic)
        (Lsp_position.render_error reason)
