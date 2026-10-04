let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "native interactive downgraded",
      yes "no-interactive-element-to-noninteractive-role"
        "<button role=\"presentation\" />" );
    ( "native interactive role",
      no "no-interactive-element-to-noninteractive-role"
        "<button role=\"button\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
