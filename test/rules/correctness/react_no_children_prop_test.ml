let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "children prop",
      yes "no-children-prop" "<Panel children={React.string(\"Settings\")} />"
    );
    ( "children syntax",
      no "no-children-prop" "<Panel> {React.string(\"Settings\")} </Panel>" );
    ("punned children", yes "no-children-prop" "<Panel children />");
    ("optional children", no "no-children-prop" "<Panel children=?children />");
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
