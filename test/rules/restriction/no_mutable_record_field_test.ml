let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "mutable interface",
      check ~kind:Interface "no-mutable-record-field" 1
        "type state = {mutable count: int}" );
    ( "multiple mutable fields",
      check "no-mutable-record-field" 2
        "type state = {mutable a: int, mutable b: int}" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "no-mutable-record-field",
          "type state = {mutable count: int}",
          "type state = {count: int}" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
