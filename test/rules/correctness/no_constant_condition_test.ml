let checks_control_flow_rules_test_support =
  let open Control_flow_rules_test_support in
  [
    ("literal condition", constant_condition "let x = if true {1} else {2}");
    ("constant while condition", constant_condition "while true {work()}");
    ( "constant switch guard",
      constant_condition "switch value {| Some(x) if true => x | None => 0}" );
    ("exact range", if exact_range then Ok () else Error "range mismatch");
    ("linter integration", if integrated then Ok () else Error "not integrated");
  ]

let () = Rule_test_runner.run checks_control_flow_rules_test_support
