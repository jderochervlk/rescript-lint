let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "wildcard switch",
      check "no-single-case-switch" 1 "switch work() {| _ => 1}" );
    ( "guarded switch",
      check "no-single-case-switch" 0 "switch input {| x if ready => work(x)}"
    );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-single-case-switch",
          "let value = switch input {| x => work(x)}",
          "let value = switch input {| Some(x) => work(x)}" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
