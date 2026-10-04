let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  []
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [ ("no-while", "while ready {work()}", "let value = work()") ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
