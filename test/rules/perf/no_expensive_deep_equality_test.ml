let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "deep array comparison",
      yes "no-expensive-deep-equality" "let same = [1] == [2]" );
    ( "primitive deep equality",
      no "no-expensive-deep-equality" "let same = 1 == 2" );
    ( "deep record comparison",
      yes "no-expensive-deep-equality"
        "type state = {a: int, b: int, c: int}\n\
         let same = (left: state, right: state) => left == right" );
    ( "deep unknown boundary",
      boundary "no-expensive-deep-equality"
        "let same = (left, right) => left == right" );
    ( "tuple deep risk",
      yes "no-expensive-deep-equality" "let same = (1, 2, 3) == (1, 2, 4)" );
    ( "option deep risk",
      yes "no-expensive-deep-equality" "let same = Some([1]) == Some([2])" );
    ( "payload variant deep risk",
      yes "no-expensive-deep-equality"
        "type status = Active(int)\n\
         let same = (left: status, right: status) => left == right" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
