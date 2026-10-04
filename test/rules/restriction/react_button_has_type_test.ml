let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ("button type missing", yes "button-has-type" "<button />");
    ("button type explicit", no "button-has-type" "<button type_=\"button\" />");
    ( "button submit explicit",
      no "button-has-type" "<button type_=\"submit\" />" );
    ("button dynamic type", no "button-has-type" "<button type_={kind} />");
    ("button spread type unknown", no "button-has-type" "<button {...props} />");
    ("custom button", no "button-has-type" "<Button />");
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
