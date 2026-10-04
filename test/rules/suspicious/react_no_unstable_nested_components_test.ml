let checks_react_semantic_rules_test_support =
  let open React_semantic_rules_test_support in
  [
    ( "nested module component",
      nested 1
        "@react.component let make = () => {module Row = {@react.component let \
         make = () => <span />}\n\
         <Row />}" );
    ( "module component stable",
      nested 0
        "module Row = {@react.component let make = () => <span />}\n\
         @react.component let make = () => <Row />" );
    ( "local ordinary function",
      nested 0
        "@react.component let make = () => {let helper = () => ()\n<div />}" );
  ]

let () = Rule_test_runner.run checks_react_semantic_rules_test_support
