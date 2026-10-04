let checks_control_flow_rules_test_support =
  let open Control_flow_rules_test_support in
  [
    ("constant binary", constant_binary "let x = true && false");
    ("constant true conjunction", constant_binary "let x = true && true");
    ("constant false disjunction", constant_binary "let x = false || false");
    ("constant true disjunction", constant_binary "let x = ready || true");
    ("constant comparison", constant_binary "let x = 2 >= 1");
    ("integer equality", constant_binary "let x = 2 == 2");
    ("integer inequality", constant_binary "let x = 2 != 1");
    ("integer maximum", constant_binary "let x = 2147483647 > 0");
    ("integer minimum", constant_binary "let x = -2147483648 < 0");
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
    ( "constant binary with an effectful operand",
      constant_binary "let x = false && sideEffect()" );
  ]

let () = Rule_test_runner.run checks_control_flow_rules_test_support
