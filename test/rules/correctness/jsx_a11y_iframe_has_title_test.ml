let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("missing frame title", yes "iframe-has-title" "<iframe />");
    ("frame title", no "iframe-has-title" "<iframe title=\"Map\" />");
    ( "typed property",
      no "iframe-has-title" "<iframe title={(\"Map\": string)} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
