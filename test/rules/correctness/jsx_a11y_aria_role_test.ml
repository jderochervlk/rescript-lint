let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("invalid role", yes "aria-role" "<div role=\"clickable\" />");
    ("abstract role", yes "aria-role" "<div role=\"widget\" />");
    ("role fallback", no "aria-role" "<div role=\"future-role button\" />");
    ("dynamic role", no "aria-role" "<div role={role} />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
