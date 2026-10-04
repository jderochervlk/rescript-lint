let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ( "function exceeds line limit",
      check ~limits:lines [ "max-lines-per-function" ] "let run = () => {\n1\n}"
    );
    ( "blank lines counted",
      check ~limits:lines [ "max-lines-per-function" ] "let run = () => {\n\n1}"
    );
    ( "function parameters are not separate spans",
      check ~limits:lines
        [ "max-lines-per-function" ]
        "let run = (first, second) => {\nfirst + second\n}" );
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
