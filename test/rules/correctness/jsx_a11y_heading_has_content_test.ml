let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("empty heading", yes "heading-has-content" "<h2 />");
    ( "heading content",
      no "heading-has-content" "<h2> {React.string(\"Settings\")} </h2>" );
    ( "unknown own visibility",
      no "heading-has-content" "<h2 ariaHidden={hidden} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
