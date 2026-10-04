let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "hook order",
      hook_order 1 "Vitest.afterEach(clean); Vitest.beforeEach(setup)" );
    ( "complete hook order",
      hook_order 0
        "Vitest.beforeAll(setup); Vitest.beforeEach(setup); \
         Vitest.afterEach(clean); Vitest.afterAll(clean)" );
    ( "before all after each",
      hook_order 1 "Vitest.beforeEach(setup); Vitest.beforeAll(setup)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
