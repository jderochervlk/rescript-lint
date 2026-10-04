let checks_react_semantic_rules_test_support =
  let open React_semantic_rules_test_support in
  [
    ( "memo render props",
      props 1
        "@react.component let make = React.memo(() => <Item items={[1]} />)" );
    ( "memo comparator not render",
      props 1
        "@react.component let make = React.memo(() => <Item items={[1]} />, \
         (_, _) => {ignore(<Item items={[1]} />)\n\
         true})" );
    ( "forwardRef render props",
      props 1
        "@react.component let make = React.forwardRef((_, _) => <Item \
         items={[1]} />)" );
    ( "unresolved wrapper not render",
      props 0
        "@react.component let make = Other.wrap(() => <Item items={[1]} />)" );
    ( "array prop",
      props 1 "@react.component let make = () => <Item items={[1, 2]} />" );
    ( "function prop",
      props 1
        "@react.component let make = () => <Item onSelect={item => \
         choose(item)} />" );
    ( "record prop",
      props 1
        "@react.component let make = () => <Item data={{name: \"hello\"}} />" );
    ( "tuple prop",
      props 1 "@react.component let make = () => <Item data={(1, 2)} />" );
    ( "stable prop",
      props 0
        "let items = [1]\n@react.component let make = () => <Item items />" );
    ("outside render", props 0 "let item = <Item items={[1]} />");
    ( "literal prop",
      props 0 "@react.component let make = () => <Item value=1 />" );
    ( "nested callback not render",
      props 0
        "@react.component let make = () => {let handler = () => <Item \
         items={[1]} />\n\
         <div />}" );
  ]

let () = Rule_test_runner.run checks_react_semantic_rules_test_support
