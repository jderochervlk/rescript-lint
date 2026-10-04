let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "unassociated label",
      yes "label-has-associated-control"
        "<label> {React.string(\"Name\")} </label>" );
    ( "nested control",
      no "label-has-associated-control" "<label> <input /> </label>" );
    ( "explicit association",
      no "label-has-associated-control"
        "<label htmlFor=\"name\"> {React.string(\"Name\")} </label>" );
    ( "nested control remains associated",
      no "label-has-associated-control"
        "<label> <span> <input /> </span> </label>" );
    ( "sibling control does not associate a label",
      yes "label-has-associated-control" "<> <label /> <input /> </>" );
    ( "nested hidden input does not associate a label",
      yes "label-has-associated-control"
        "<label> <input type_=\"hidden\" /> </label>" );
    ( "nonlabel is not checked for associated controls",
      no "label-has-associated-control" "<div> <input /> </div>" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
