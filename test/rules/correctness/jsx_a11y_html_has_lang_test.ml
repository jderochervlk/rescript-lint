let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("missing document language", yes "html-has-lang" "<html />");
    ("document language", no "html-has-lang" "<html lang=\"en\" />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
