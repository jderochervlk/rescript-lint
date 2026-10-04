let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "float erasing excluded",
      check "no-erasing-operation" 0 "let f = (x: float) => x *. 0.0" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-erasing-operation",
          "let erase = (x: int) => x * 0",
          "let erase = (x: int) => x * 2" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
