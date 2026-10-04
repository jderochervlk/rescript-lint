let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "string accumulating concat",
      yes "no-accumulating-concat"
        "let value = [\"a\"]->Array.reduce(\"\", (acc, part) => acc ++ part)" );
    ( "nonaccumulating callback",
      no "no-accumulating-concat"
        "let value = [\"a\"]->Array.reduce(\"\", (_acc, part) => part ++ \
         \"suffix\")" );
    ( "named reduce callback",
      no "no-accumulating-concat"
        "let combine = (a, b) => a + b\n\
         let value = Array.reduce([1], 0, combine)" );
    ( "nonconcat reducer",
      no "no-accumulating-concat"
        "let value = Array.reduce([1], 0, (acc, item) => acc + item)" );
    ( "list accumulating concat",
      yes "no-accumulating-concat"
        "let value = List.reduce(list{\"a\"}, \"\", (acc, item) => acc ++ item)"
    );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
