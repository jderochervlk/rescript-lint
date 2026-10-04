let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "mouse click without keys",
      yes "click-events-have-key-events" "<div onClick={_ => action()} />" );
    ( "keyboard pair",
      no "click-events-have-key-events"
        "<div onClick={_ => action()} onKeyDown={_ => action()} />" );
    ( "native keyboard",
      no "click-events-have-key-events" "<button onClick={_ => action()} />" );
    ( "presentation click",
      no "click-events-have-key-events"
        "<div role=\"presentation\" onClick={_ => action()} />" );
    ( "unknown click visibility",
      no "click-events-have-key-events"
        "<div ariaHidden={hidden} onClick={_ => action()} />" );
    ( "unknown presentation role",
      no "click-events-have-key-events"
        "<div role={role} onClick={_ => action()} />" );
    ( "fallback presentation role",
      no "click-events-have-key-events"
        "<div role=\"none button\" onClick={_ => action()} />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
