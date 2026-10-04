let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "inner HTML conflict",
      yes "no-danger-with-children"
        "<div dangerouslySetInnerHTML={html}> {React.string(\"Fallback\")} \
         </div>" );
    ( "inner HTML alone",
      no "no-danger-with-children" "<div dangerouslySetInnerHTML={html} />" );
    ( "custom inner HTML semantics",
      no "no-danger-with-children"
        "<Panel dangerouslySetInnerHTML={html}> {React.string(\"Fallback\")} \
         </Panel>" );
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
