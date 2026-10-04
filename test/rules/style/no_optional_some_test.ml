let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "optional None",
      check "no-optional-some" 0 "let value = consume(~name=?None, ())" );
    ( "Some mandatory",
      check "no-optional-some" 0 "let value = consume(~name=Some(1), ())" );
    ( "Some shadow",
      check "no-optional-some" 0
        "type custom = Some(int)\nlet value = consume(~name=?Some(1), ())" );
    ( "unknown open Some",
      check "no-optional-some" 0
        "open Other\nlet value = consume(~name=?Some(1), ())" );
    ( "two optional arguments",
      check "no-optional-some" 2
        "let value = consume(~a=?Some(1), ~b=?Some(2), ())" );
    ("linter and suppressions", integration);
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-optional-some",
          "let value = consume(~name=?Some(compute()), ())",
          "let value = consume(~name=?maybe, ())" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
