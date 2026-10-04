let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ( "too many parameters",
      check ~limits:params [ "max-params" ]
        "let run = (first, second, third) => first + second + third" );
    ( "labeled parameters count once",
      check ~limits:params [ "max-params" ]
        "let run = (~first, ~second, ~third) => first + second + third" );
    ( "optional parameters count once",
      check ~limits:params [ "max-params" ]
        "let run = (~first=1, ~second=2, ~third=3) => first + second + third" );
    ( "returned function exceeds parameters",
      check ~limits:params [ "max-params" ]
        "let run = first => (second, third, fourth) => first + second + third \
         + fourth" );
    ( "default callback gets checked",
      check ~limits:params [ "max-params" ]
        "let run = (~callback=(first, second, third) => first + second + \
         third) => callback" );
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
