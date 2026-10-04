let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "active descendant focus",
      yes "aria-activedescendant-has-tabindex"
        "<div ariaActivedescendant=\"selected\" />" );
    ( "active descendant tabindex",
      no "aria-activedescendant-has-tabindex"
        "<div ariaActivedescendant=\"selected\" tabIndex=0 />" );
    ( "native active descendant focus",
      no "aria-activedescendant-has-tabindex"
        "<input ariaActivedescendant=\"selected\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
