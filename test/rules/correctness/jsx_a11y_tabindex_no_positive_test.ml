let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("positive tabindex", yes "tabindex-no-positive" "<input tabIndex=2 />");
    ("zero tabindex", no "tabindex-no-positive" "<input tabIndex=0 />");
    ("dynamic tabindex", no "tabindex-no-positive" "<input tabIndex={index} />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
