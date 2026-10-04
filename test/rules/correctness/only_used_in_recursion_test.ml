let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "forwarded recursion parameter",
      yes "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == 0 {()} else \
         {repeat(count - 1, config)}" );
    ( "used recursion parameter",
      no "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == config {()} else \
         {repeat(count - 1, config)}" );
    ( "changed recursion parameter",
      no "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == 0 {()} else \
         {repeat(count - 1, config + 1)}" );
    ( "recursive labels changed",
      no "only-used-in-recursion"
        "let rec swap = (~left, ~right) => swap(~right=left, ~left=right)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
