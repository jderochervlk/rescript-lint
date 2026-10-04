let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "redundant mutual recursion",
      yes "no-redundant-mutual-recursion"
        "let rec increment = x => x + 1 and double = x => x * 2" );
    ( "required mutual recursion",
      no "no-redundant-mutual-recursion"
        "let rec even = n => if n == 0 {true} else {odd(n - 1)} and odd = n => \
         if n == 0 {false} else {even(n - 1)}" );
    ( "single recursive function",
      no "no-redundant-mutual-recursion"
        "let rec repeat = n => if n == 0 {()} else {repeat(n - 1)}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
