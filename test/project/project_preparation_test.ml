open Rescript_linter

let ( let* ) = Result.bind
let require condition detail = if condition then Ok () else Error detail

let unit_ filename text =
  let kind =
    if Filename.check_suffix filename ".resi" then Source.Interface
    else Source.Implementation
  in
  let source = Source.{ filename = "/preparation/" ^ filename; text; kind } in
  let* tree = Result.map_error Lint_error.render (Parser.parse source) in
  Ok
    Project_files.
      { name = Project_files.module_name filename; source; tree; modified = 0. }

let config =
  let* disabled =
    List.fold_left
      (fun result (rule : Rule_config.rule) ->
        let* config = result in
        Rule_config.set config ~id:rule.id ~enabled:false)
      (Ok Rule_config.default) Rule_config.rules
  in
  let* throws =
    Rule_config.set disabled ~id:"no-unhandled-throws" ~enabled:true
  in
  let* config = Rule_config.set throws ~id:"no-deprecated-api" ~enabled:true in
  Rule_config.with_overrides ~base:"/preparation" config
    (`List
       [
         `Assoc
           [
             ("paths", `List [ `String "Other.res"; `String "Other.resi" ]);
             ( "rules",
               `Assoc
                 [
                   ("no-deprecated-api", `Bool false);
                   ("no-unhandled-throws", `Bool false);
                 ] );
           ];
       ])

let fixture =
  let* api = unit_ "Api.res" "let read = () => 1\nlet old = true" in
  let* interface =
    unit_ "Api.resi"
      "exception Missing\n\
       @throws(Missing) let read: unit => int\n\
       @deprecated let old: int"
  in
  let* entry = unit_ "Entry.res" "let value = Api.old\nApi.read()" in
  let* other = unit_ "Other.res" "let value = Api.old\nApi.read()" in
  let* caller_interface = unit_ "Other.resi" "let value: int" in
  let* bad = unit_ "Bad.resi" "@throws(Unknown) let fail: unit => int" in
  Ok
    ( Project_files.
        {
          root = "/preparation";
          units = [ api; interface; entry; other; caller_interface; bad ];
        },
      [ entry; other; caller_interface ],
      bad )

let finish config source document findings =
  List.filter
    (fun item -> Rule_config.enabled config item.Diagnostic.rule)
    findings
  |> Suppressions.apply
       ~known_rules:
         (List.map (fun rule -> rule.Rule_config.id) Rule_config.rules)
       ~source document
  |> Source_range.sort

let equivalence =
  let* project, callers, _ = fixture in
  let* base = config in
  let options =
    {
      Project_options.default with
      entry_modules = [ "Entry" ];
      deep_equality_threshold = 7;
    }
  in
  let base = Rule_config.with_options options base in
  let prepared = Project_context.prepare (Some project) in
  let throws = Throws_project.prepare project in
  let* () =
    List.fold_left
      (fun result (unit_ : Project_files.unit_) ->
        let* () = result in
        let source = unit_.source in
        let config = Rule_config.for_file ~filename:source.filename base in
        let context = Project_context.context ~config ~source prepared in
        let* () =
          require
            (context = Project_context.semantic ~config ~source (Some project)
            && context.enabled = Rule_config.enabled_ids config
            && context.entry_module = (unit_.name = "Entry")
            && context.deep_equality_threshold = 7)
            "Prepared context lost per-file activation"
        in
        let* document =
          Result.map_error Lint_error.render (Parser.parse_document source)
        in
        let prepared_result =
          Result.map
            (finish config source document)
            (Rule_checks.check ~config ~context ~project:(Some project) ~source
               document)
        in
        let public_result =
          Linter.lint_source_with_loader
            ~load_project:(fun ~config:_ ~overlay:_ -> Ok (Some project))
            base source
        in
        let* () =
          require
            (prepared_result = public_result)
            "Prepared/end-to-end findings differ"
        in
        let* () =
          require
            (Throws_project.check_prepared ~source unit_.tree throws
            = Throws_project.check ~project ~source unit_.tree)
            "Prepared/public throws findings differ"
        in
        require
          (match prepared_result with
          | Ok findings when unit_.name = "Entry" -> List.length findings = 2
          | Ok [] when unit_.name = "Other" -> true
          | _ -> false)
          "Override or interface findings changed")
      (Ok ()) callers
  in
  let source = (List.hd callers).Project_files.source in
  let different =
    Rule_config.with_options
      { options with entry_modules = []; deep_equality_threshold = 2 }
      base
  in
  let context = Project_context.context ~config:different ~source prepared in
  require
    ((not context.entry_module) && context.deep_equality_threshold = 2)
    "Preparation retained another caller's options"

let error_filtering =
  let* project, callers, bad = fixture in
  let prepared = Throws_project.prepare project in
  let entry = List.hd callers in
  let* () =
    require
      (Throws_project.relevant_errors ~source:entry.source entry.tree prepared
       = []
      && List.exists
           (fun (name, errors) -> name = "Bad" && errors <> [])
           (Throws_project.annotation_errors prepared)
      && Result.is_error (Throws_project.exported_scope prepared))
      "Unrelated errors leaked to a caller or escaped export validation"
  in
  let* caller = unit_ "Caller.res" "Bad.fail()" in
  let result =
    Throws_project.check_prepared ~source:caller.source caller.tree prepared
  in
  let* () =
    require
      (Result.is_error result
      && result
         = Throws_project.check ~project ~source:caller.source caller.tree)
      "Relevant provider error changed"
  in
  require
    (Throws_project.check_prepared ~source:bad.source bad.tree prepared
    = Throws_project.check ~project ~source:bad.source bad.tree)
    "Interface provider error changed"

let activation_and_rebuild =
  let* caller = unit_ "Caller.res" "let value = Api.old" in
  let* plain = unit_ "Api.resi" "let old: int" in
  let project =
    Project_files.{ root = "/preparation"; units = [ plain; caller ] }
  in
  let before = Project_context.prepare (Some project) in
  let* changed = unit_ "Api.resi" "@deprecated let old: int" in
  let updated = { project with units = [ changed; caller ] } in
  let after = Project_context.prepare (Some updated) in
  let* config = config in
  let context prepared =
    Project_context.context ~config ~source:caller.source prepared
  in
  let* () =
    require
      (context before <> context after)
      "Rebuilt preparation reused stale signatures"
  in
  let* () =
    require
      ((not (Throws_project.active ~project ~source:caller.source caller.tree))
      && Throws_project.check_prepared ~source:caller.source caller.tree
           (Throws_project.prepare project)
         = Ok []
      && Throws_project.active ~scope:Throws_scope.initial ~project
           ~source:caller.source caller.tree)
      "Imported scope or inactive caller activation changed"
  in
  let* throwing =
    unit_ "Api.resi" "exception Missing\n@throws(Missing) let old: int"
  in
  let updated = { project with units = [ throwing; caller ] } in
  require
    (Throws_project.annotation_errors (Throws_project.prepare project)
    <> Throws_project.annotation_errors (Throws_project.prepare updated))
    "Rebuilt throws preparation retained stale annotation errors"

let failure_ordering =
  let* project, _, _ = fixture in
  let* caller = unit_ "Caller.res" "Bad.fail()" in
  let* config = config in
  let* config = Rule_config.set config ~id:"jsx-a11y/alt-text" ~enabled:true in
  let config =
    Rule_config.with_options
      {
        Project_options.default with
        throws_dependencies = [ "/missing-dependency" ];
      }
      config
  in
  let lint config source =
    Linter.lint_source_with_loader
      ~load_project:(fun ~config:_ ~overlay:_ -> Ok (Some project))
      config source
  in
  let* () =
    require
      (match lint config caller.source with
      | Error (Lint_error.Analysis_errors (first, [])) ->
          first.rule = "adapter-analysis"
      | _ -> false)
      "Dependency or project throws errors preceded framework validation"
  in
  let* config =
    Rule_config.set config ~id:"forbidden-source-root-reference" ~enabled:true
  in
  let* () =
    require
      (match lint config caller.source with
      | Error (Lint_error.Analysis_errors (first, [])) ->
          first.rule = "source-root-analysis"
      | _ -> false)
      "Framework validation preceded provenance preparation errors"
  in
  require
    (match lint config { caller.source with text = "let =" } with
    | Error (Lint_error.Parse_errors _) -> true
    | _ -> false)
    "Preparation preceded caller parse errors"

let dependency_preparation =
  let open Dependency_package_test_support in
  temporary
    [
      ( "tools",
        manifest ~namespace:(`String "Tools") "tools",
        [ ("src/Api.resi", "@deprecated let value: int") ] );
    ]
    (fun root roots ->
      let local =
        install root
          ( "local",
            manifest ~namespace:(`String "Local") "local",
            [
              ("src/Entry.res", "let value = Tools.Api.value");
              ("src/Other.resi", "let value: int");
            ] )
      in
      let* config = config in
      let* config =
        Rule_config.set config ~id:"forbidden-source-root-reference"
          ~enabled:true
      in
      let config =
        Rule_config.with_options
          {
            Project_options.default with
            root = Some local;
            source_root_dependencies = roots;
            entry_modules = [ "Entry" ];
          }
          config
      in
      let* project =
        Result.map_error Lint_error.render
          (Project_files.load ~root:local ~excluded:[] ())
      in
      let* prepared =
        Result.map_error Lint_error.render
          (Project_context.prepare_with_dependencies ~config (Some project))
      in
      let* () =
        List.fold_left
          (fun result (unit_ : Project_files.unit_) ->
            let* () = result in
            let source = unit_.source in
            let context = Project_context.context ~config ~source prepared in
            require
              (Ok context
               = Project_context.semantic_with_dependencies ~config ~source
                   (Some project)
              && context.namespace_roots = [ "Local"; "Tools" ]
              && List.mem_assoc "Tools" context.module_signatures
              && List.mem_assoc "Local" context.module_signatures)
              "Prepared dependency context differs")
          (Ok ()) project.units
      in
      Yojson.Basic.to_file
        (Filename.concat local "rescript.json")
        (manifest ~namespace:(`String "Entry") "local");
      let failed =
        Project_context.prepare_with_dependencies ~config (Some project)
      in
      let* () =
        require (Result.is_error failed)
          "Namespace collision escaped preparation"
      in
      List.fold_left
        (fun result (unit_ : Project_files.unit_) ->
          let* () = result in
          require
            (match
               Project_context.semantic_with_dependencies ~config
                 ~source:unit_.source (Some project)
             with
            | Error (Lint_error.Analysis_errors (first, [])) ->
                first.filename = unit_.source.filename
                && first.rule = "source-root-analysis"
            | _ -> false)
            "Preparation error retained another caller's filename")
        (Ok ()) project.units)

let () =
  List.iter
    (fun (name, result) ->
      match result with
      | Ok () -> ()
      | Error detail -> failwith (name ^ ": " ^ detail))
    [
      ("equivalence", equivalence);
      ("error filtering", error_filtering);
      ("activation and rebuild", activation_and_rebuild);
      ("failure ordering", failure_ordering);
      ("dependency preparation", dependency_preparation);
    ]
