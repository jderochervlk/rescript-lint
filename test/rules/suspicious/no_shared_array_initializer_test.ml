let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "shared mutable record",
      yes "no-shared-array-initializer"
        "type item = {mutable selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "shared nested array",
      yes "no-shared-array-initializer" "let values = Array.make(~length=3, [])"
    );
    ( "immutable record initializer",
      no "no-shared-array-initializer"
        "type item = {selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "single initializer slot",
      no "no-shared-array-initializer" "let values = Array.make(~length=1, [])"
    );
    ( "conflicting record mutability is unknown",
      no "no-shared-array-initializer"
        "type mutableItem = {mutable selected: bool}\n\
         type fixedItem = {selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "immutable array fill",
      no "no-shared-array-initializer" "let values = Array.make(~length=3, 0)"
    );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
