let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ("top-level test", top_level 1 "Vitest.test(\"works\", cb)");
    ( "test inside suite",
      top_level 0 "Vitest.describe(\"suite\", () => Vitest.test(\"works\", cb))"
    );
    ( "named describe callback",
      top_level 0
        "let tests = () => Vitest.test(\"works\", cb)\n\
         Vitest.describe(\"suite\", tests)" );
    ( "dormant suite ownership unknown",
      top_level 0 "let register = () => Vitest.test(\"works\", cb)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
