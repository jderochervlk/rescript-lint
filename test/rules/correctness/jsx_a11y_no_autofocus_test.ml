let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("autofocus", yes "no-autofocus" "<input autoFocus=true />");
    ("false autofocus", no "no-autofocus" "<input autoFocus=false />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
