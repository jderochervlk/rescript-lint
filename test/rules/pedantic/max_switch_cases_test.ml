let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "switch cases",
      check ~max_switch_cases:1 "max-switch-cases" 1
        "switch value {| Some(x) => x | None => 0}" );
    ( "switch boundary",
      check ~max_switch_cases:2 "max-switch-cases" 0
        "switch value {| Some(x) => x | None => 0}" );
    ( "or patterns one arm",
      check ~max_switch_cases:1 "max-switch-cases" 0
        "switch value {| A | B => 0}" );
  ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
