let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "manual list map",
      yes "prefer-standard-combinator"
        "let rec doubleAll = items => switch items {| list{} => list{} | \
         list{head, ...tail} => list{head * 2, ...doubleAll(tail)}}" );
    ( "effectful recursion excluded",
      no "prefer-standard-combinator"
        "let rec mapped = items => switch items {| list{} => list{} | \
         list{head, ...tail} => list{log(head), ...mapped(tail)}}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
