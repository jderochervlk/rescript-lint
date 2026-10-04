let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "same sibling test title",
      duplicate_title 1
        "open Vitest\n\
         describe(\"suite\", () => {test(\"same\", cb); it(\"same\", cb)})" );
    ( "same sibling suite title",
      duplicate_title 1
        "Vitest.describe(\"same\", cb); Vitest.describe(\"same\", cb)" );
    ( "different sibling title",
      duplicate_title 0
        "Vitest.test(\"first\", cb); Vitest.test(\"second\", cb)" );
    ( "different suites permit same title",
      duplicate_title 0
        "open Vitest\n\
         describe(\"a\", () => test(\"same\", cb)); describe(\"b\", () => \
         test(\"same\", cb))" );
    ( "suite and test titles distinct categories",
      duplicate_title 0
        "Vitest.describe(\"same\", cb); Vitest.test(\"same\", cb)" );
    ( "dynamic title conservative",
      duplicate_title 0 "Vitest.test(name, cb); Vitest.test(name, cb)" );
    ( "named callback titles not double counted",
      duplicate_title 0
        "let register = () => Vitest.test(\"works\", cb)\n\
         Vitest.describe(\"suite\", register)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
