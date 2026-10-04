let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "mod shadow",
      check "no-modulo-one" 0
        "let mod = (x, y) => x + y\nlet f = (x: int) => mod(x, 1)" );
    ( "qualified custom modulo",
      check "no-modulo-one" 0 "let f = (x: int) => Other.mod(x, 1)" );
    ("mod negative", check "no-modulo-one" 1 "let f = (x: int) => mod(x, -1)");
    ("mod operator", check "no-modulo-one" 1 "let f = (x: int) => x % 1");
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-modulo-one",
          "let modulo = (x: int) => mod(x, 1)",
          "let modulo = (x: int) => mod(x, 2)" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
