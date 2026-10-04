let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "static interactions",
      yes "no-static-element-interactions" "<span onClick={_ => action()} />" );
    ( "role interactions",
      no "no-static-element-interactions"
        "<span role=\"button\" onClick={_ => action()} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
