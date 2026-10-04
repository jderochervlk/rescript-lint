let checks_exception_rules_test_support =
  let open Exception_rules_test_support in
  [
    ("debugger", debugger "let inspect = () => {%debugger; value}");
    ( "debugger in nested module",
      debugger "module M = {let f = () => %debugger}" );
    ( "multiple debugger expressions",
      check
        [ "no-debugger"; "no-debugger" ]
        "let f = () => {%debugger; %debugger}" );
    ( "debugger exact range",
      exact_range "no-debugger" "// before\n%debugger" 10 19 );
  ]

let () = Rule_test_runner.run checks_exception_rules_test_support
