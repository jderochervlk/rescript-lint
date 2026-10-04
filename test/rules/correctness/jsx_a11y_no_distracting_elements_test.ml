let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("distracting element", yes "no-distracting-elements" "<marquee />");
    ("ordinary element", no "no-distracting-elements" "<p />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
