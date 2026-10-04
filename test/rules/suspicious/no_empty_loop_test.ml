let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ("empty for", check "no-empty-loop" 1 "for i in 2 downto 0 {()}");
    ("annotated empty loop", check "no-empty-loop" 1 "while ready {((): unit)}");
    ("effectful loop", check "no-empty-loop" 0 "while ready {work(); ()}");
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [ ("no-empty-loop", "while ready {()}", "while ready {work()}") ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
