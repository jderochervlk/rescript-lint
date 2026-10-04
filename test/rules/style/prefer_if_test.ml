let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "boolean reverse switch",
      check "prefer-if" 1 "switch ready {| false => 1 | true => 2}" );
    ( "boolean guard",
      check "prefer-if" 0 "switch ready {| true if another => 1 | false => 2}"
    );
    ( "boolean duplicate",
      check "prefer-if" 0 "switch ready {| true => 1 | true => 2}" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "prefer-if",
          "let value = switch ready {| true => 1 | false => 2}",
          "let value = switch ready {| Some(x) => x | None => 2}" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
