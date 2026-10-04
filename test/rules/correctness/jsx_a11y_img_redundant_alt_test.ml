let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "redundant image word",
      yes "img-redundant-alt" "<img alt=\"Image of a logo\" />" );
    ("descriptive alternative", no "img-redundant-alt" "<img alt=\"Acme\" />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
