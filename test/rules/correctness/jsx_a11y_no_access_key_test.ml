let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("access key", yes "no-access-key" "<button accessKey=\"s\" />");
    ("no access key", no "no-access-key" "<button />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
