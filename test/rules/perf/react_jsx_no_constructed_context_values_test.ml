let checks_react_semantic_rules_test_support =
  let open React_semantic_rules_test_support in
  [
    ( "context allocation",
      context 1
        "module Theme = {let context = React.createContext(0)\n\
         let make = React.Context.provider(context)}\n\
         @react.component let make = (~children) => <Theme value={{color: \
         \"blue\"}}> children </Theme>" );
    ( "ordinary value prop",
      context 0
        "@react.component let make = () => <Theme value={{color: \"blue\"}} />"
    );
    ( "stable context",
      context 0
        "module Theme = {let context = React.createContext(0)\n\
         let make = React.Context.provider(context)}\n\
         let theme = {color: \"blue\"}\n\
         @react.component let make = () => <Theme value=theme />" );
  ]

let () = Rule_test_runner.run checks_react_semantic_rules_test_support
