let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("invalid scope", yes "scope" "<td scope=\"col\" />");
    ("header scope", no "scope" "<th scope=\"col\" />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
