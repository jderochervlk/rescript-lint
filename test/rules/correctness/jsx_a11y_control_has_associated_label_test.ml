let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "control label missing",
      yes "control-has-associated-label" "<input type_=\"search\" />" );
    ( "explicit control label",
      no "control-has-associated-label" "<input ariaLabel=\"Search\" />" );
    ( "wrapped label",
      no "control-has-associated-label"
        "<label> {React.string(\"Search\")} <input /> </label>" );
    ( "linked label",
      no "control-has-associated-label"
        "<> <label htmlFor=\"search\"> {React.string(\"Search\")} </label> \
         <input id=\"search\" /> </>" );
    ( "hidden input",
      no "control-has-associated-label" "<input type_=\"hidden\" />" );
    ( "submit native label",
      no "control-has-associated-label" "<input type_=\"submit\" />" );
    ( "empty associated label",
      yes "control-has-associated-label" "<label> <input /> </label>" );
    ( "unknown ancestor visibility",
      no "control-has-associated-label" "<div hidden={hidden}> <input /> </div>"
    );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
