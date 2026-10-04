let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "partial head",
      yes "no-partial-function" "let first = value => List.headOrThrow(value)"
    );
    ( "partial result",
      yes "no-partial-function" "let unwrap = value => Result.getExn(value)" );
    ( "safe head",
      no "no-partial-function" "let first = value => List.head(value)" );
    ( "invalid-value inventory separate",
      no "no-partial-function" "let first = value => Array.getUnsafe(value, 0)"
    );
    ( "partial indexed list",
      yes "no-partial-function" "let read = xs => List.getOrThrow(xs, 0)" );
    ( "partial indexed legacy list",
      yes "no-partial-function" "let read = xs => List.getExn(xs, 0)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
