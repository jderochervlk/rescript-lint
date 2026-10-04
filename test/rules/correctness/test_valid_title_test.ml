let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ("for title index", title 1 "Vitest.For.test([1], \"\", (_, _) => ())");
    ( "for describe async",
      title 1 "Vitest.For.describeAsync([1], \"\", async _ => ())" );
    ("in-source API", title 1 "Vitest.InSource.test(\"\", _ => ())");
    ( "binding in-source alias",
      title 1 "Vitest_Bindings.InSource.describe(\"\", () => ())" );
    ( "nested binding in-source alias",
      title 1 "Vitest.Bindings.InSource.itAsync(\"\", async _ => ())" );
    ("empty test title", title 1 "Vitest.test(\"\", cb)");
    ("whitespace suite title", title 1 "Vitest.describe(\"  \", cb)");
    ("nonempty title", title 0 "Vitest.test(\"works\", cb)");
    ("dynamic title", title 0 "Vitest.test(title, cb)");
    ( "dormant callback invalid title",
      title 1 "let register = () => Vitest.test(\"\", cb)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
