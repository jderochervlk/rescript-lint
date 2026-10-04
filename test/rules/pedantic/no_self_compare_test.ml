let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "self compare",
      yes "no-self-compare" "let value = 1\nlet same = value == value" );
    ( "different values",
      no "no-self-compare"
        "let left = 1\nlet right = 2\nlet same = left == right" );
    ( "self compare aliases",
      yes "no-self-compare"
        "let value = 1\nlet alias = value\nlet same = value === alias" );
    ("call comparison", no "no-self-compare" "let value = read() == read()");
    ( "field comparison",
      no "no-self-compare" "let check = value => value.field == value.field" );
    ( "float self comparison",
      yes "no-self-compare" "let check = (value: float) => value != value" );
    ( "external global reads are not stable",
      no "no-self-compare"
        "@val external current: int = \"current\"\n\
         let same = current == current" );
    ( "external snapshot is distinct from later global read",
      no "no-self-compare"
        "@val external current: int = \"current\"\n\
         let captured = current\n\
         let same = captured == current" );
    ( "captured external snapshot is stable",
      yes "no-self-compare"
        "@val external current: int = \"current\"\n\
         let captured = current\n\
         let same = captured == captured" );
    ( "self comparison unknown boundary",
      boundary "no-self-compare" "let same = value => value == value" );
    ( "boolean API result",
      yes "no-self-compare"
        "let value = Array.isEmpty([])\nlet same = value == value" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
