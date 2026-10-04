open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "control.res"; text; kind }

let check ?kind expected text =
  let source = source ?kind text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let actual =
        Control_flow_rules.check ~source tree
        |> List.map (fun (diagnostic : Diagnostic.t) -> diagnostic.rule)
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " actual)
             text)

let clean text = check [] text
let constant_condition text = check [ "no-constant-condition" ] text
let constant_binary text = check [ "no-constant-binary-expression" ] text
let duplicate text = check [ "no-duplicate-condition" ] text
let identical text = check [ "no-identical-branches" ] text

let binary_truth expected text =
  let source = source text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree -> (
      match Control_flow_rules.check ~source tree with
      | [ diagnostic ]
        when diagnostic.rule = "no-constant-binary-expression"
             && diagnostic.message
                = "This binary expression always evaluates to "
                  ^ string_of_bool expected ^ "." ->
          Ok ()
      | diagnostics ->
          Error
            ("Unexpected truth findings: "
            ^ String.concat "; "
                (List.map
                   (fun (diagnostic : Diagnostic.t) -> diagnostic.message)
                   diagnostics)))

let parser_string expected text =
  match Parser.parse (source ("let value = " ^ text)) with
  | Ok
      (Implementation
         [
           {
             pstr_desc =
               Pstr_value
                 ( _,
                   [
                     {
                       pvb_expr =
                         {
                           pexp_desc = Pexp_constant (Pconst_string (raw, None));
                           _;
                         };
                       _;
                     };
                   ] );
             _;
           };
         ])
    when raw = expected ->
      Ok ()
  | Ok _ -> Error "Unexpected ordinary string representation"
  | Error error -> Error (Lint_error.render error)

let exact_range =
  match
    let source = source "// comment\nlet value = if true {1} else {2}\n" in
    Result.bind (Parser.parse source) (fun tree ->
        Ok (Control_flow_rules.check ~source tree))
  with
  | Ok [ diagnostic ] ->
      diagnostic.rule = "no-constant-condition"
      && diagnostic.range.start.line = 2
      && diagnostic.range.start.column = 16
      && diagnostic.range.finish.column = 20
  | _ -> false

let integrated =
  match Linter.lint_source (source "let value = if true {1} else {2}") with
  | Ok diagnostics ->
      List.exists
        (fun (diagnostic : Diagnostic.t) ->
          diagnostic.rule = "no-constant-condition")
        diagnostics
  | Error _ -> false

let synthetic_clean funct =
  let argument name =
    Ast_helper.Exp.construct (Location.mknoloc (Longident.Lident name)) None
  in
  let expression =
    Ast_helper.Exp.apply funct
      [ (Nolabel, argument "true"); (Nolabel, argument "false") ]
  in
  let source = source "" in
  Control_flow_rules.check ~source
    (Parser.Implementation [ Ast_helper.Str.eval expression ])
  = []

let functor_path =
  synthetic_clean
    (Ast_helper.Exp.ident
       (Location.mknoloc
          (Longident.Lapply (Longident.Lident "F", Longident.Lident "G"))))

let non_identifier_callee =
  synthetic_clean
    (Ast_helper.Exp.construct (Location.mknoloc (Longident.Lident "Some")) None)

let checks =
  [
    ("literal condition", constant_condition "let x = if true {1} else {2}");
    ( "literal comparison condition",
      check
        [ "no-constant-condition"; "no-constant-binary-expression" ]
        "if 2 < 1 {a} else {b}" );
    ("dynamic condition", clean "let x = if isReady {1} else {2}");
    ("constant binary", constant_binary "let x = true && false");
    ("constant true conjunction", constant_binary "let x = true && true");
    ("constant false disjunction", constant_binary "let x = false || false");
    ("constant true disjunction", constant_binary "let x = ready || true");
    ("unknown conjunction", clean "let x = ready && true");
    ("unknown disjunction", clean "let x = ready || false");
    ("constant comparison", constant_binary "let x = 2 >= 1");
    ("integer equality", constant_binary "let x = 2 == 2");
    ("integer inequality", constant_binary "let x = 2 != 1");
    ("integer maximum", constant_binary "let x = 2147483647 > 0");
    ("integer minimum", constant_binary "let x = -2147483648 < 0");
    ("integer above supported range", clean "let x = 2147483648 > 0");
    ("integer below supported range", clean "let x = -2147483649 < 0");
    ("integer outside Int64 range", clean "let x = 999999999999999999999999 > 0");
    ("float equality", constant_binary "let x = 2.5 === 2.5");
    ("float ordering", constant_binary "let x = 2.5 < 3.0");
    ("string inequality", constant_binary "let x = \"a\" !== \"b\"");
    ("string ordering", constant_binary "let x = \"a\" <= \"b\"");
    ("escaped string equality", binary_truth true {|let x = "\u0061" == "a"|});
    ("escaped string ordering", binary_truth true {|let x = "\n" < "a"|});
    ("escaped right string", binary_truth true {|let x = "a" == "\u0061"|});
    ( "equivalent escape spellings",
      binary_truth true {|let x = "\n" === "\u000a"|} );
    ("escaped unequal strings", binary_truth false {|let x = "\t" == "\n"|});
    ("literal escape text differs", binary_truth false {|let x = "\\b" == "\b"|});
    ( "escape supported by JSON and JavaScript",
      binary_truth true {|let x = "\/" == "/"|} );
    ("hex remains unknown", clean {|let x = "\x61" == "a"|});
    ("decimal remains unknown", clean {|let x = "\097" == "a"|});
    ("braced Unicode remains unknown", clean {|let x = "\u{61}" == "a"|});
    ("identity escape remains unknown", clean {|let x = "\q" == "q"|});
    ("short null remains unknown", clean {|let x = "\0" == "\u0000"|});
    ("vertical tab remains unknown", clean {|let x = "\v" == "\u000b"|});
    ("templates remain excluded", clean {|let x = `a` == "a"|});
    ("tagged templates remain excluded", clean {|let x = custom`a` == "a"|});
    ("escaped templates remain excluded", clean {|let x = `\u0061` == "a"|});
    ("parser retains escape spelling", parser_string {|\u0061\n|} {|"\u0061\n"|});
    ("parser rewrites decimal escape to hex", parser_string {|\x61|} {|"\097"|});
    ( "unicode string equality",
      constant_binary "let x = \"\240\159\152\128\" == \"\240\159\152\128\"" );
    ( "unicode string inequality",
      constant_binary "let x = \"\195\169\" != \"a\"" );
    ( "unicode ordering uses UTF16",
      binary_truth true "let x = \"\240\159\152\128\" < \"\238\128\128\"" );
    ( "unicode ordering rejects UTF8 byte ordering",
      binary_truth false "let x = \"\238\128\128\" < \"\240\159\152\128\"" );
    ("unicode right ordering", binary_truth true "let x = \"a\" < \"\195\169\"");
    ( "unicode not normalized",
      binary_truth false "let x = \"\195\169\" == \"e\204\129\"" );
    ("character equality", constant_binary "let x = 'a' == 'a'");
    ("character ordering", constant_binary "let x = 'b' > 'a'");
    ("boolean equality", constant_binary "let x = true == false");
    ("mismatched literals", clean "let x = 1 == \"1\"");
    ("unsupported integer suffix", clean "let x = 1n == 1n");
    ( "constant binary with an effectful operand",
      constant_binary "let x = false && sideEffect()" );
    ("dynamic binary", clean "let x = isReady && isEnabled");
    ("constant while condition", constant_condition "while true {work()}");
    ( "constant switch guard",
      constant_condition "switch value {| Some(x) if true => x | None => 0}" );
    ( "duplicate else-if condition",
      duplicate "if status == #ready {a} else if status == #ready {b} else {c}"
    );
    ( "three duplicate conditions are reported once each",
      check
        [ "no-duplicate-condition"; "no-duplicate-condition" ]
        "if ready {a} else if ready {b} else if ready {c} else {d}" );
    ( "duplicate constant conditions are deduplicated",
      check
        [
          "no-constant-condition";
          "no-duplicate-condition";
          "no-constant-condition";
        ]
        "if true {a} else if true {b} else {c}" );
    ( "effectful conditions are not assumed stable",
      clean "if isReady() {a} else if isReady() {b} else {c}" );
    ( "mutable-looking field reads are not assumed stable",
      clean "if state.ready {a} else if state.ready {b} else {c}" );
    ( "stable constructor conditions",
      duplicate
        "if value == Some(ready) {a} else if value == Some(ready) {b} else {c}"
    );
    ( "stable tuple conditions",
      duplicate
        "if value == (ready, #active) {a} else if value == (ready, #active) \
         {b} else {c}" );
    ( "same switch guard on distinct patterns",
      clean
        "switch value {| Some(x) if ready => x | None if ready => 0 | _ => 1}"
    );
    ( "duplicate switch guards on the same pattern",
      duplicate
        "switch value {| Some(x) if ready => x | Some(x) if ready => 0 | _ => \
         1}" );
    ( "switch guards with differently positioned bindings",
      clean
        "switch value {| (Some(x), _) if x => 1 | (_, Some(x)) if x => 2 | _ \
         => 3}" );
    ( "intervening effects reset duplicate conditions",
      clean
        "if left == right {a} else if mutate() {b} else if left == right {c} \
         else {d}" );
    ( "stable intervening tests preserve duplicate conditions",
      duplicate "if ready {a} else if enabled {b} else if ready {c} else {d}" );
    ( "intervening effects reset duplicate guards",
      clean
        "switch value {| Some(x) if ready => x | Some(x) if mutate() => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
    ( "intervening different patterns preserve stable duplicate guards",
      duplicate
        "switch value {| Some(x) if ready => x | None if enabled => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
    ("identical if branches", identical "if ready {render()} else {render()}");
    ( "identical adjacent else-if branches",
      identical "if ready {render()} else if blocked {render()} else {wait()}"
    );
    ( "three duplicate switch guards report later occurrences only",
      check
        [ "no-duplicate-condition"; "no-duplicate-condition" ]
        "switch value {| Some(x) if ready => x | Some(x) if ready => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
    ("different branches", clean "if ready {render()} else {wait()}");
    ( "comments do not distinguish branches",
      identical "if ready {/* first */ render()} else {/* second */ render()}"
    );
    ( "identical switch branches",
      identical "switch value {| Some(_) => render() | None => render()}" );
    ( "switch bodies with differently scoped bindings",
      clean "switch value {| (Some(x), _) => x | (_, Some(x)) => x | _ => 0}" );
    ( "switch bodies with binding on one side only",
      clean "switch value {| Some(x) => x | None => x}" );
    ( "identical switch bodies independent of bindings",
      identical "switch value {| Some(x) => render() | None => render()}" );
    ( "same-pattern identical switch bodies",
      identical "switch value {| Some(x) if ready => x | Some(x) => x | _ => 0}"
    );
    ( "alias-bound switch bodies",
      clean "switch value {| Some(_) as x => x | None => x}" );
    ( "module-unpack switch bodies have distinct scopes",
      clean
        "switch value {| (module(M), _) => M.value | (_, module(M)) => M.value}"
    );
    ( "right module-unpack switch body",
      clean
        "switch value {| (Some(_), _) => M.value | (_, module(M)) => M.value}"
    );
    ( "same module-unpack pattern preserves identical body detection",
      identical
        "switch value {| module(M) if ready => M.value | module(M) => M.value}"
    );
    ("standalone constant attribute", clean "@@example(if true {1} else {2})");
    ("standalone comparison attribute", clean "@@example(1 == 1)");
    ( "standalone interface attribute",
      check ~kind:Source.Interface [] "@@example(if true {1} else {2})" );
    ("interface", check ~kind:Source.Interface [] "let ready: bool");
    ("if without else", clean "if ready {render()}");
    ("functor application path", if functor_path then Ok () else Error "path");
    ( "non-identifier callee",
      if non_identifier_callee then Ok () else Error "callee" );
    ("exact range", if exact_range then Ok () else Error "range mismatch");
    ("linter integration", if integrated then Ok () else Error "not integrated");
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
