let checks_expression_rules_test_support =
  let open Expression_rules_test_support in
  [
    ("literal concat", concat "let greeting = \"Hello, \" ++ \"world\"");
    ("empty left concat", concat "let value = \"\" ++ read()");
    ("empty right concat", concat "let value = read() ++ \"\"");
    ("both empty", concat "let value = \"\" ++ \"\"");
    ("typed empty concat", concat "let value = read() ++ (\"\": string)");
    ("nested literal concat", concat "let value = read() ++ (\"a\" ++ \"b\")");
    ("nested callback", concat "let value = items->Array.map(x => x ++ \"\")");
  ]

let () = Rule_test_runner.run checks_expression_rules_test_support
