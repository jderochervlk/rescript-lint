let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "noninteractive handlers",
      yes "no-noninteractive-element-interactions"
        "<div onClick={_ => action()} />" );
    ( "interactive handlers",
      no "no-noninteractive-element-interactions"
        "<button onClick={_ => action()} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
