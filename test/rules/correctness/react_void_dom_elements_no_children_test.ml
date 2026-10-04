let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "void children",
      yes "void-dom-elements-no-children"
        "<img src=\"logo.png\"> {React.string(\"Logo\")} </img>" );
    ( "void children prop",
      yes "void-dom-elements-no-children" "<input children={child} />" );
    ( "void inner HTML",
      yes "void-dom-elements-no-children"
        "<br dangerouslySetInnerHTML={html} />" );
    ("void empty", no "void-dom-elements-no-children" "<img src=\"logo.png\" />");
    ( "ordinary children",
      no "void-dom-elements-no-children" "<div> {React.string(\"Text\")} </div>"
    );
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
