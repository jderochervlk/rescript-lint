let checks_expression_rules_test_support =
  let open Expression_rules_test_support in
  [
    ("if booleans", boolean "let value = if ready {true} else {false}");
    ("inverse if", boolean "let value = if ready {false} else {true}");
    ( "if effectful condition",
      boolean "let value = if read() {true} else {false}" );
    ("boolean equality", boolean "let value = ready == true");
    ("strict equality", boolean "let value = ready === false");
    ("boolean inequality", boolean "let value = ready != false");
    ("strict inequality", boolean "let value = true !== ready");
    ("left boolean", boolean "let value = false == read()");
    ("literal comparison", boolean "let value = true == false");
    ("and left neutral", boolean "let value = true && read()");
    ("and right neutral", boolean "let value = read() && true");
    ("or left neutral", boolean "let value = false || read()");
    ("or right neutral", boolean "let value = read() || false");
    ("double negation", boolean "let value = !!read()");
    ("typed bool", boolean "let value = ready == (true: bool)");
    ( "typed expression counted once",
      boolean "let value = (ready == true: bool)" );
    ("switch booleans", boolean "switch ready {| true => true | false => false}");
    ( "switch inverted",
      boolean "switch read() {| false => true | true => false}" );
    ( "nested function",
      boolean "module Nested = {let compute = ready => ready == true}" );
  ]

let () = Rule_test_runner.run checks_expression_rules_test_support
