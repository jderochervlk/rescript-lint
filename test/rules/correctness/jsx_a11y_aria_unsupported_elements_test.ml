let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "unsupported metadata",
      yes "aria-unsupported-elements" "<meta ariaHidden=true />" );
    ("ordinary aria", no "aria-unsupported-elements" "<div ariaHidden=true />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "metadata explicit role",
        Jsx_rules_test_support.check "aria-unsupported-elements" 1
          "let view = <meta role=\"button\" />" );
      ( "metadata without semantics",
        Jsx_rules_test_support.check "aria-unsupported-elements" 0
          "let view = <meta />" );
    ]
