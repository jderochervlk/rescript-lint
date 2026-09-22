open Rescript_linter

let source text = Source.{ filename = "rules.res"; kind = Implementation; text }
let configured id enabled = Rule_config.set Rule_config.default ~id ~enabled

let lint_config id enabled text =
  Result.bind (configured id enabled) (fun rules ->
      Linter.lint_source_with_rules rules (source text)
      |> Result.map_error Lint_error.render)

let has_rule id diagnostics =
  List.exists
    (fun (diagnostic : Diagnostic.t) -> diagnostic.rule = id)
    diagnostics

let toggled id text =
  match (lint_config id true text, lint_config id false text) with
  | Ok enabled, Ok disabled -> has_rule id enabled && not (has_rule id disabled)
  | _ -> false

let lint rules filename =
  let text = if filename = "clean.res" then "let x = 1" else "Console.log(1)" in
  Linter.lint_source_with_rules rules (source text)

let run arguments = Application.run ~lint ~fix:lint arguments

let selected arguments id expected =
  match Command.parse arguments with
  | Ok (Lint { rules; _ } | Fix { rules; _ } | Watch { rules; _ })
  | Ok (Language_server rules) ->
      Rule_config.enabled rules id = expected
  | _ -> false

let optional_family ids expected =
  ids = expected
  && List.filter_map
       (fun (rule : Rule_config.rule) ->
         if List.mem rule.id ids && not rule.enabled_by_default then
           Some rule.id
         else None)
       Rule_config.rules
     = expected

let default_quiet text =
  match Linter.lint_source (source text) with Ok [] -> true | _ -> false

let mixed_optional_families =
  let configured =
    Result.bind (configured "no-useless-concat" true) (fun config ->
        Rule_config.set config ~id:"no-empty-function" ~enabled:true)
  in
  match configured with
  | Error _ -> false
  | Ok config -> (
      match
        Linter.lint_source_with_rules config
          (source "let text = \"a\" ++ \"b\"\nlet empty = () => ()")
      with
      | Ok diagnostics ->
          List.map (fun (finding : Diagnostic.t) -> finding.rule) diagnostics
          = [ "no-useless-concat"; "no-empty-function" ]
      | Error _ -> false)

let checks =
  [
    ( "123 unique registered rules",
      List.length Rule_config.rules = 123
      && List.length
           (List.sort_uniq String.compare
              (List.map (fun (r : Rule_config.rule) -> r.id) Rule_config.rules))
         = 123 );
    ( "defaults follow registry",
      List.for_all
        (fun (r : Rule_config.rule) ->
          Rule_config.enabled Rule_config.default r.id = r.enabled_by_default)
        Rule_config.rules );
    ( "expression registry order and disabled defaults",
      optional_family Expression_rules.rule_ids
        [
          "simplify-boolean-expression"; "no-useless-concat"; "approx-constant";
        ] );
    ( "policy registry order and disabled defaults",
      optional_family Policy_rules.rule_ids
        [
          "no-empty-function";
          "no-empty-file";
          "no-warning-comments";
          "max-nesting";
          "max-params";
          "max-lines-per-function";
        ] );
    ( "default expression pack stays quiet",
      default_quiet "let text = \"a\" ++ \"b\"\nlet pi = 3.14159" );
    ( "default policy pack stays quiet",
      default_quiet "// TODO\nlet empty = () => ()" );
    ("both optional packs preserve finding order", mixed_optional_families);
    ("unknown rule", configured "typo" true = Error "Unknown rule: typo");
    ( "unknown names disabled",
      not (Rule_config.enabled Rule_config.default "typo") );
    ("list rules", (run [ "--list-rules" ]).stdout = [ Rule_config.listing ]);
    ("default console", (run [ "bad.res" ]).outcome = Findings);
    ( "disable console",
      (run [ "--disable-rule"; "no-console"; "bad.res" ]).outcome = Clean );
    ( "last flag wins",
      (run
         [
           "--disable-rule";
           "no-console";
           "--enable-rule";
           "no-console";
           "bad.res";
         ])
        .outcome = Findings );
    ( "last disable wins",
      (run
         [
           "--enable-rule";
           "no-console";
           "bad.res";
           "--disable-rule";
           "no-console";
         ])
        .outcome = Clean );
    ( "unknown enable rejected",
      (run [ "--enable-rule"; "typo"; "bad.res" ]).stderr
      = [ "Unknown rule: typo" ] );
    ( "unknown disable rejected",
      (run [ "--disable-rule"; "typo"; "bad.res" ]).outcome = Failed );
    ( "missing ID",
      (run [ "--enable-rule" ]).stderr = [ "--enable-rule requires a rule ID." ]
    );
    ( "flag is not ID",
      (run [ "--disable-rule"; "--fix"; "bad.res" ]).stderr
      = [ "--disable-rule requires a rule ID." ] );
    ( "literal flags",
      Command.parse [ "--"; "--enable-rule"; "no-console" ]
      = Ok
          (Lint
             {
               files = [ "--enable-rule"; "no-console" ];
               rules = Rule_config.default;
             }) );
    ( "fix selection",
      selected
        [ "--fix"; "--enable-rule"; "no-empty-file"; "a.res" ]
        "no-empty-file" true );
    ( "watch selection",
      selected
        [ "--watch"; "--disable-rule"; "no-debugger"; "a.res" ]
        "no-debugger" false );
    ( "LSP selection",
      selected
        [ "lsp"; "--enable-rule"; "no-warning-comments"; "--stdio" ]
        "no-warning-comments" true );
    ( "plain selection",
      selected [ "--disable-rule"; "no-console"; "a.res" ] "no-console" false );
    ("not a selection", not (selected [ "--help" ] "no-console" true));
    ("invalid selection", not (selected [] "no-console" true));
    ("LSP needs runtime", (run [ "lsp"; "--stdio" ]).outcome = Failed);
    ( "files still required",
      (run [ "--enable-rule"; "no-empty-file" ]).outcome = Failed );
    ("debugger", toggled "no-debugger" "%debugger");
    ( "useless catch",
      toggled "no-useless-catch" "try work() catch { | error => throw(error) }"
    );
    ( "catch-all",
      toggled "no-catch-all-exception" "try work() catch { | _ => () }" );
    ("boolean", toggled "simplify-boolean-expression" "let x = ready == true");
    ("concat", toggled "no-useless-concat" "let x = \"a\" ++ \"b\"");
    ("constant", toggled "approx-constant" "let x = 3.14159");
    ("empty function", toggled "no-empty-function" "let f = () => ()");
    ("empty file", toggled "no-empty-file" "// empty");
    ( "warning comment",
      toggled "no-warning-comments" "// TODO: finish this\nlet x = 1" );
    ("parameters", toggled "max-params" "let f = (a, b, c, d, e, f) => a");
    ( "nesting",
      toggled "max-nesting" "if a {if b {if c {if d {if e {work()}}}}}" );
    ( "function lines",
      toggled "max-lines-per-function"
        ("let f = () => {\n"
        ^ String.concat "\n" (List.init 52 (fun _ -> "work()"))
        ^ "\n}") );
    ( "parse failures cannot be disabled",
      match lint_config "no-debugger" false "let =" with
      | Error _ -> true
      | _ -> false );
    ( "disabled throws skips analysis",
      match
        lint_config "no-unhandled-throws" false
          "@throws external load: unit => promise<int> = \"load\""
      with
      | Ok _ -> true
      | _ -> false );
    ( "default file API",
      match Linter.lint_file "fixtures/example.res" with
      | Ok [] -> true
      | _ -> false );
    ( "configured file API",
      match
        Linter.lint_file_with_rules Rule_config.default "fixtures/example.res"
      with
      | Ok [] -> true
      | _ -> false );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
