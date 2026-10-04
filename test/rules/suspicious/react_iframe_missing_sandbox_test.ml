let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "iframe sandbox missing",
      yes "iframe-missing-sandbox" "<iframe src=\"/embed\" />" );
    ( "iframe sandbox provided",
      no "iframe-missing-sandbox" "<iframe sandbox=\"\" />" );
    ( "iframe dynamic sandbox",
      no "iframe-missing-sandbox" "<iframe sandbox={policy} />" );
    ( "iframe optional sandbox",
      no "iframe-missing-sandbox" "<iframe sandbox=?policy />" );
    ("custom iframe exempt", no "iframe-missing-sandbox" "<Frames.iframe />");
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
