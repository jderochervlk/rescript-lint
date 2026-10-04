let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ("empty file", check [ "no-empty-file" ] "");
    ("whitespace file", check [ "no-empty-file" ] " \n\t");
    ("comment-only file", check [ "no-empty-file" ] "// explanation\n");
    ( "module-attribute-only file",
      check [ "no-empty-file" ] "@@warning(\"-44\")" );
    ( "standalone attributes do not contain executable functions",
      check [ "no-empty-file" ] "@@example(() => ())" );
    ("empty-file location", check_range "no-empty-file" 1 1 1 1 " \n");
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
