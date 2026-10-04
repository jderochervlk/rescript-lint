let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "nested describes over limit",
      depth 1
        "open Vitest\n\
         describe(\"a\", () => describe(\"b\", () => describe(\"c\", cb)))" );
    ( "nested describes at limit",
      depth 0 "open Vitest\ndescribe(\"a\", () => describe(\"b\", cb))" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
