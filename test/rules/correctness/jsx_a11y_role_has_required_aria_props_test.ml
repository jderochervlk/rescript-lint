let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "required checked state",
      yes "role-has-required-aria-props" "<div role=\"checkbox\" />" );
    ( "checked state provided",
      no "role-has-required-aria-props"
        "<div role=\"checkbox\" ariaChecked=#\"true\" />" );
    ( "native checked semantics",
      no "role-has-required-aria-props"
        "<input type_=\"checkbox\" role=\"checkbox\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
