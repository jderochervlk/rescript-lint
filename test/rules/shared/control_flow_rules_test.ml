open Rescript_linter
open Control_flow_rules_test_support

let clean text = check [] text

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
    ( "literal comparison condition",
      check
        [ "no-constant-condition"; "no-constant-binary-expression" ]
        "if 2 < 1 {a} else {b}" );
    ("dynamic condition", clean "let x = if isReady {1} else {2}");
    ("unknown conjunction", clean "let x = ready && true");
    ("unknown disjunction", clean "let x = ready || false");
    ("integer above supported range", clean "let x = 2147483648 > 0");
    ("integer below supported range", clean "let x = -2147483649 < 0");
    ("integer outside Int64 range", clean "let x = 999999999999999999999999 > 0");
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
    ("mismatched literals", clean "let x = 1 == \"1\"");
    ("unsupported integer suffix", clean "let x = 1n == 1n");
    ("dynamic binary", clean "let x = isReady && isEnabled");
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
    ( "same switch guard on distinct patterns",
      clean
        "switch value {| Some(x) if ready => x | None if ready => 0 | _ => 1}"
    );
    ( "switch guards with differently positioned bindings",
      clean
        "switch value {| (Some(x), _) if x => 1 | (_, Some(x)) if x => 2 | _ \
         => 3}" );
    ( "intervening effects reset duplicate conditions",
      clean
        "if left == right {a} else if mutate() {b} else if left == right {c} \
         else {d}" );
    ( "intervening effects reset duplicate guards",
      clean
        "switch value {| Some(x) if ready => x | Some(x) if mutate() => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
    ("different branches", clean "if ready {render()} else {wait()}");
    ( "switch bodies with differently scoped bindings",
      clean "switch value {| (Some(x), _) => x | (_, Some(x)) => x | _ => 0}" );
    ( "switch bodies with binding on one side only",
      clean "switch value {| Some(x) => x | None => x}" );
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
    ("standalone constant attribute", clean "@@example(if true {1} else {2})");
    ("standalone comparison attribute", clean "@@example(1 == 1)");
    ( "standalone interface attribute",
      check ~kind:Source.Interface [] "@@example(if true {1} else {2})" );
    ("interface", check ~kind:Source.Interface [] "let ready: bool");
    ("if without else", clean "if ready {render()}");
    ("functor application path", if functor_path then Ok () else Error "path");
    ( "non-identifier callee",
      if non_identifier_callee then Ok () else Error "callee" );
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
