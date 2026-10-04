let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "nested alternative",
      check "no-nested-ternary" 1 "let value = a ? 1 : b ? 2 : 3" );
    ( "nested condition",
      check "no-nested-ternary" 1 "let value = (a ? b : c) ? 1 : 2" );
    ( "nested if not ternary",
      check "no-nested-ternary" 0
        "let value = if a {if b {1} else {2}} else {3}" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-nested-ternary",
          "let value = a ? (b ? 1 : 2) : 3",
          "let value = a ? 1 : 2" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
