let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "hooks after test",
      hooks_top 1 "Vitest.test(\"first\", cb); Vitest.beforeEach(setup)" );
    ( "hooks before test",
      hooks_top 0 "Vitest.beforeEach(setup); Vitest.test(\"first\", cb)" );
    ( "parent hook after nested suite",
      hooks_top 1 "Vitest.describe(\"nested\", cb); Vitest.afterAll(clean)" );
    ( "nested hook independent of parent tests",
      hooks_top 0
        "Vitest.test(\"first\", cb); Vitest.describe(\"nested\", () => \
         Vitest.beforeEach(setup))" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
