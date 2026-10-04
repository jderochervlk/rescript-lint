let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "mouse focus missing",
      yes "mouse-events-have-key-events" "<div onMouseOver={_ => action()} />"
    );
    ( "mouse focus pair",
      no "mouse-events-have-key-events"
        "<div onMouseOver={_ => action()} onFocus={_ => action()} />" );
    ( "mouse leave missing blur",
      yes "mouse-events-have-key-events" "<div onMouseLeave={_ => action()} />"
    );
    ( "mouse blur pair",
      no "mouse-events-have-key-events"
        "<div onMouseOut={_ => action()} onBlur={_ => action()} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
