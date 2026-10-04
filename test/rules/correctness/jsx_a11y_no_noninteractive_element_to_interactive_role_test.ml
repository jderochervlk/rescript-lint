let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "noninteractive role upgraded",
      yes "no-noninteractive-element-to-interactive-role"
        "<li role=\"button\" />" );
    ( "permitted list role",
      no "no-noninteractive-element-to-interactive-role"
        "<li role=\"menuitem\" />" );
    ( "generic role",
      no "no-noninteractive-element-to-interactive-role"
        "<div role=\"button\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
