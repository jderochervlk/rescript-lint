let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "interactive role focus",
      yes "interactive-supports-focus"
        "<div role=\"button\" onClick={_ => action()} />" );
    ( "interactive role focused",
      no "interactive-supports-focus"
        "<div role=\"button\" tabIndex=0 onClick={_ => action()} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
