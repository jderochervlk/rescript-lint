let checks_expression_rules_test_support =
  let open Expression_rules_test_support in
  [
    ("pi", constant "let value = 3.141592653589793");
    ("rounded pi", constant "let value = 3.14159");
    ("truncated pi", constant "let value = 3.141592");
    ("exponent", constant "let value = 3.141592653589793e0");
    ("underscores", constant "let value = 3.141_592_653_589_793");
  ]

let () = Rule_test_runner.run checks_expression_rules_test_support
