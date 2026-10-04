let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "native tag preferred",
      yes "prefer-tag-over-role" "<div role=\"button\" />" );
    ("native tag used", no "prefer-tag-over-role" "<button role=\"button\" />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
