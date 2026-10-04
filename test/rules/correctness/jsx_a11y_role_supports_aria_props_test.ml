let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "unsupported role state",
      yes "role-supports-aria-props"
        "<article role=\"article\" ariaChecked=#\"true\" />" );
    ( "supported role state",
      no "role-supports-aria-props"
        "<div role=\"checkbox\" ariaChecked=#\"true\" />" );
    ( "global role property",
      no "role-supports-aria-props"
        "<article role=\"article\" ariaLabel=\"Story\" />" );
    ( "prohibited generic name",
      yes "role-supports-aria-props"
        "<div role=\"generic\" ariaLabel=\"Story\" />" );
    ( "presentation globals",
      no "role-supports-aria-props"
        "<div role=\"presentation\" ariaHidden=true />" );
    ( "implicit unsupported state",
      yes "role-supports-aria-props" "<button ariaChecked=#\"true\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
