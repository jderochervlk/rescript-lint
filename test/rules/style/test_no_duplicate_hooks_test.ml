let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "duplicate before hook",
      duplicate_hook 1 "Vitest.beforeEach(reset); Vitest.beforeEach(reset)" );
    ( "async hook same identity",
      duplicate_hook 1 "Vitest.beforeEach(reset); Vitest.beforeEachAsync(reset)"
    );
    ( "hook scopes independent",
      duplicate_hook 0
        "open Vitest\n\
         beforeEach(reset); describe(\"nested\", () => beforeEach(reset))" );
    ( "hook alias identity",
      duplicate_hook 1
        "let setup = Vitest.beforeAll\nsetup(reset); Vitest.beforeAll(reset)" );
    ( "duplicate after hooks",
      duplicate_hook 2
        "Vitest.afterEach(clean); Vitest.afterEachAsync(clean); \
         Vitest.afterAll(clean); Vitest.afterAllAsync(clean)" );
    ( "explicit beforeAll FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"beforeAll\"\n\
         setup(cb); Vitest.beforeAll(cb)" );
    ( "explicit beforeEach FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"beforeEach\"\n\
         setup(cb); Vitest.beforeEach(cb)" );
    ( "explicit afterEach FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"afterEach\"\n\
         setup(cb); Vitest.afterEach(cb)" );
    ( "explicit afterAll FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"afterAll\"\n\
         setup(cb); Vitest.afterAll(cb)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
