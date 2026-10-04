let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ("unknown integer", check "no-identity-operation" 0 "let f = x => x + 0");
    ( "float identity excluded",
      check "no-identity-operation" 0 "let f = (x: float) => x +. 0.0" );
    ( "attribute payload ignored",
      check "no-identity-operation" 0 "@example(1 + 0) let value = 1" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-identity-operation",
          "let identity = (x: int) => x + 0",
          "let identity = (x: int) => x + 2" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
