let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ( "nested conditional",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {if active {run()} else {wait()}} else {stop()}" );
    ( "nested else body",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {run()} else {let value = 1; if active {wait()} else \
         {stop()}}" );
    ( "deep nesting reported at first excess",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {if active {if valid {run()}}}" );
    ( "switch nesting",
      check ~limits:nesting [ "max-nesting" ]
        "switch value {| Some(x) => if ready {x} else {0} | None => 0}" );
    ( "while nesting",
      check ~limits:nesting [ "max-nesting" ] "while ready {if active {run()}}"
    );
    ( "for nesting",
      check ~limits:nesting [ "max-nesting" ]
        "for i in 0 to 10 {if active {run(i)}}" );
    ( "try nesting",
      check ~limits:nesting [ "max-nesting" ]
        "try {if active {run()}} catch {| _ => recover()}" );
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
