let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "obj interface",
      check ~kind:Interface "no-obj-external" 1
        "@obj external make: (~name: string) => 'a = \"\"" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-obj-external",
          "@obj external make: (~name: string) => 'a = \"\"",
          "@val external make: string => int = \"make\"" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "legacy object external",
        New_policy_rules_test_support.check "no-obj-external" 1
          "@bs.obj external create: (~value: int) => unit = \"\"" );
    ]
