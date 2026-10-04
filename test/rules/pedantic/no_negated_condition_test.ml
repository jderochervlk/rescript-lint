let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ("no else", check "no-negated-condition" 0 "if !ready {work()}");
    ( "named not shadow",
      check "no-negated-condition" 0
        "let not = x => x\nlet value = if not(ready) {1} else {2}" );
    ( "negated ternary",
      check "no-negated-condition" 1 "let value = !ready ? 1 : 2" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-negated-condition",
          "let value = if !ready {1} else {2}",
          "let value = if ready {1} else {2}" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
