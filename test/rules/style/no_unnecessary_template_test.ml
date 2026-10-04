let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ("empty template", check "no-unnecessary-template" 1 "let value = ``");
    ( "multiline template",
      check "no-unnecessary-template" 1 "let value = `a\nb`" );
    ( "tagged template",
      check "no-unnecessary-template" 0 "let value = tag`hello`" );
    ( "json template",
      check "no-unnecessary-template" 0 "let value = json`{\"a\":1}`" );
    ( "ordinary string",
      check "no-unnecessary-template" 0 "let value = \"hello\"" );
    ( "two interpolations",
      check "no-unnecessary-template" 0 "let value = `${a} ${b}`" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-unnecessary-template",
          "let value = `hello`",
          "let value = `hello ${name}`" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
