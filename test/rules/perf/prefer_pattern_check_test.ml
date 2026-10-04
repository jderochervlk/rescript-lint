let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "fixed list pattern",
      yes "prefer-pattern-check"
        "let same = (items: list<int>) => items == list{1, 2}" );
    ( "efficient empty list comparison",
      no "prefer-pattern-check"
        "let same = (items: list<int>) => items == list{}" );
    ( "efficient None comparison",
      no "prefer-pattern-check"
        "let same = (value: option<int>) => value == None" );
    ( "literal variant pattern",
      yes "prefer-pattern-check"
        "type status = Active(int)\n\
         let same = (left: status) => left == Active(1)" );
    ( "dynamic list pattern excluded",
      no "prefer-pattern-check"
        "let same = (items: list<int>, value) => items == list{value}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
