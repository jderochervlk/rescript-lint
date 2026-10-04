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
      [
        ( "no-for",
          "for index in 0 to 2 {work(index)}",
          "let value = [1, 2]->Array.map(work)" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
