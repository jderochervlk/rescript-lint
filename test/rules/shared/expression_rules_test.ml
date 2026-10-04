open Rescript_linter
open Expression_rules_test_support

let clean = check []

let check_range text expected =
  Result.bind (diagnostics text) (function
    | [ diagnostic ] ->
        let start = diagnostic.range.start.byte_offset in
        let length = diagnostic.range.finish.byte_offset - start in
        if String.sub text start length = expected && diagnostic.fixes = [] then
          Ok ()
        else Error "Unexpected diagnostic range or fix"
    | _ -> Error "Expected one diagnostic")

let constant_message literal name =
  Result.bind
    (diagnostics ("let value = " ^ literal))
    (function
      | [ diagnostic ] ->
          let expected = "This literal approximates " ^ name ^ "." in
          if diagnostic.message = expected then Ok ()
          else Error diagnostic.message
      | _ -> Error "Expected one constant diagnostic")

let synthetic_clean expression =
  let source = source "" in
  let tree = Parser.Implementation [ Ast_helper.Str.eval expression ] in
  if Expression_rules.check ~source tree = [] then Ok ()
  else Error "Unexpected synthetic diagnostic"

let checks =
  [
    ( "identical branches belong to another rule",
      clean "if ready {true} else {true}" );
    ("nonliteral branch", clean "if ready {enabled} else {false}");
    ("if without else", clean "if ready {render()}");
    ("branch side effect", clean "if ready {log(); true} else {false}");
    ("dynamic comparison", clean "let value = left == right");
    ("numeric comparison", clean "let value = 1 == 1");
    ("and preserve evaluation", clean "let value = read() && false");
    ("or preserve evaluation", clean "let value = read() || true");
    ("dynamic and", clean "let value = ready && enabled");
    ("dynamic or", clean "let value = ready || enabled");
    ("single negation", clean "let value = !ready");
    ("named not calls", clean "let not = x => x\nlet value = not(not(ready))");
    ("qualified calls", clean "let value = Bool.not(Bool.not(ready))");
    ("computed callee", clean "let value = make()(true, false)");
    ( "switch repeated patterns",
      clean "switch ready {| true => true | true => false}" );
    ( "switch identical results",
      clean "switch ready {| true => true | false => true}" );
    ("switch wildcard", clean "switch ready {| true => true | _ => false}");
    ( "switch guard",
      clean "switch ready {| true if enabled => true | false => false}" );
    ( "switch last guard",
      clean "switch ready {| true => true | false if enabled => false}" );
    ( "switch nonliteral result",
      clean "switch ready {| true => enabled | false => false}" );
    ( "switch three cases",
      clean "switch ready {| true => true | false => false | _ => false}" );
    ("dynamic concat", clean "let value = left ++ right");
    ("meaningful prefix", clean "let value = \"prefix\" ++ read()");
    ("meaningful suffix", clean "let value = read() ++ \"suffix\"");
    ("no reassociation", clean "let value = \"first\" ++ read() ++ \"last\"");
    ("integer plus", clean "let value = 1 + 2");
    ("character literals", clean "let value = 'a' ++ 'b'");
    ("template literals", clean "let value = `hello ${name}`");
    ("e", constant_message "2.718281828459045" "Math.Constants.e");
    ("ln2", constant_message "0.6931471805599453" "Math.Constants.ln2");
    ("ln10", constant_message "2.302585092994046" "Math.Constants.ln10");
    ("log2e", constant_message "1.4426950408889634" "Math.Constants.log2e");
    ("log10e", constant_message "0.4342944819032518" "Math.Constants.log10e");
    ("sqrt1_2", constant_message "0.7071067811865476" "Math.Constants.sqrt1_2");
    ("sqrt2", constant_message "1.4142135623730951" "Math.Constants.sqrt2");
    ( "negative pi",
      constant_message "-3.141592653589793" "the negative of Math.Constants.pi"
    );
    ("coarse pi", clean "let value = 3.14");
    ("unrelated float", clean "let value = 3.1415");
    ("unrelated integer", clean "let value = 314159");
    ("unrelated exponent", clean "let value = 3.141592653589793e2");
    ("standard constant", clean "let value = Math.Constants.pi");
    ("infinite float", clean "let value = 1e999");
    ("string literal", clean "let value = \"3.141592653589793\"");
    ("comment", clean "// 3.141592653589793\nlet value = 0");
    ( "pattern literal",
      clean "switch value {| 3.141592653589793 => true | _ => false}" );
    ("attribute payload", clean "@example(3.141592653589793)\nlet value = 0");
    ("standalone constant attribute", clean "@@example(3.14159)");
    ("standalone boolean attribute", clean "@@example(ready == true)");
    ("standalone concat attribute", clean "@@example(\"a\" ++ \"b\")");
    ( "standalone interface attribute",
      check ~kind:Source.Interface [] "@@example(3.14159)" );
    ("interface", check ~kind:Source.Interface [] "let value: float");
    ( "interface attribute",
      check ~kind:Source.Interface []
        "@example(3.141592653589793)\nlet value: float" );
    ("concat range", check_range "let value = \"a\" ++ \"b\"" "\"a\" ++ \"b\"");
    ("boolean range", check_range "let value = ready == true" "ready == true");
    ( "constant range",
      check_range "let value = 3.141592653589793" "3.141592653589793" );
    ( "unicode prefix range",
      check_range "let prefix = \"\240\159\152\128\"; let value = ready == true"
        "ready == true" );
    ( "unicode concat range",
      check_range "let value = \"\240\159\152\128\" ++ \"\195\169\""
        "\"\240\159\152\128\" ++ \"\195\169\"" );
    ( "all rules sorted",
      check
        [
          "no-useless-concat"; "simplify-boolean-expression"; "approx-constant";
        ]
        "let a = \"a\" ++ \"b\"\nlet b = ready == true\nlet c = 3.14159" );
    ( "malformed synthetic float",
      synthetic_clean (Ast_helper.Exp.constant (Pconst_float ("invalid", None)))
    );
    ( "suffixed synthetic float",
      synthetic_clean
        (Ast_helper.Exp.constant (Pconst_float ("3.141592653589793", Some 'x')))
    );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error error -> Some (name ^ ": " ^ error))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
