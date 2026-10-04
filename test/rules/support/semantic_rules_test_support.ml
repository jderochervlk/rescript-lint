open Rescript_linter

let source text =
  Source.{ filename = "semantic.res"; text; kind = Implementation }

let diagnostics ?(context = Semantic_model.default_context) text =
  let source = source text in
  Result.bind (Parser.parse source) (Semantic_rules.check ~context ~source)

let check ?context rule expected text =
  match diagnostics ?context text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let actual =
        List.filter
          (fun (diagnostic : Diagnostic.t) -> diagnostic.rule = rule)
          diagnostics
        |> List.length
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d for %s" rule expected actual
             text)

let yes rule text = check rule 1 text
let no rule text = check rule 0 text

let boundary rule text =
  let context = { Semantic_model.default_context with enabled = [ rule ] } in
  match diagnostics ~context text with
  | Error (Lint_error.Analysis_errors _) -> Ok ()
  | Error error -> Error (Lint_error.render error)
  | Ok _ -> Error "Expected an explicit analysis boundary"

let imported =
  let source =
    Source.
      {
        filename = "Api.resi";
        kind = Interface;
        text =
          "let compute: int => promise<int>\n\
           let validate: string => result<int, string>\n\
           @deprecated(\"Use modern\")\n\
           let legacy: int => int";
      }
  in
  match Parser.parse source with
  | Ok (Interface signature) ->
      Ok
        {
          Semantic_model.default_context with
          module_signatures = [ ("Api", signature) ];
        }
  | Ok _ -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)

let imported_check rule text =
  Result.bind imported (fun context -> check ~context rule 1 text)

let with_signatures entries run =
  let parsed =
    List.fold_left
      (fun result (name, text) ->
        Result.bind result (fun signatures ->
            let source =
              Source.{ filename = name ^ ".resi"; kind = Interface; text }
            in
            match Parser.parse source with
            | Ok (Interface signature) -> Ok (signatures @ [ (name, signature) ])
            | Ok _ -> Error "Expected signature"
            | Error error -> Error (Lint_error.render error)))
      (Ok []) entries
  in
  Result.bind parsed (fun module_signatures ->
      run
        {
          Semantic_model.default_context with
          module_signatures;
          project_modules = List.map fst entries;
        })

let deprecated_constraint text reference =
  Result.bind
    (Rule_config.set Rule_config.default ~id:"no-deprecated-api" ~enabled:true)
    (fun config ->
      Result.bind
        (Result.map_error Lint_error.render
           (Linter.lint_source_with_rules config (source text)))
        (fun diagnostics ->
          match
            List.filter
              (fun (item : Diagnostic.t) -> item.rule = "no-deprecated-api")
              diagnostics
          with
          | [ item ]
            when item.message = "This API is deprecated. Use modern"
                 && item.fixes = []
                 && String.sub text item.range.start.byte_offset
                      (item.range.finish.byte_offset
                     - item.range.start.byte_offset)
                    = reference ->
              Ok ()
          | _ -> Error "Constrained public deprecation metadata was lost"))
