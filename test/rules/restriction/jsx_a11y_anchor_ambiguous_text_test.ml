let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "ambiguous link",
      yes "anchor-ambiguous-text"
        "<a href=\"/docs\"> {React.string(\"Click here!\")} </a>" );
    ( "descriptive link",
      no "anchor-ambiguous-text"
        "<a href=\"/docs\"> {React.string(\"Documentation\")} </a>" );
    ( "named ambiguous link",
      no "anchor-ambiguous-text"
        "<a href=\"/docs\" ariaLabel=\"Documentation\"> \
         {React.string(\"here\")} </a>" );
    ( "dynamic link text",
      no "anchor-ambiguous-text" "<a href=\"/docs\"> {label} </a>" );
    ( "nested link text",
      yes "anchor-ambiguous-text"
        "<a href=\"/docs\"> <span> {React.string(\"Read more\")} </span> </a>"
    );
    ( "shadowed React text",
      check "anchor-ambiguous-text" 0
        "module React = Other\n\
         let view = <a href=\"/docs\"> {React.string(\"here\")} </a>" );
    ( "open makes React ambiguous",
      check "anchor-ambiguous-text" 0
        "open Custom\n\
         let view = <a href=\"/docs\"> {React.string(\"here\")} </a>" );
    ( "known Prelude preserves React",
      with_prelude "anchor-ambiguous-text" 1 "let value: int"
        "open Prelude\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known conflicting Prelude shadows React",
      with_prelude "anchor-ambiguous-text" 0
        "module React: {let string: string => string}"
        "open Prelude\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known nested Prelude",
      with_prelude "anchor-ambiguous-text" 1 "module Nested: {let value: int}"
        "open Prelude.Nested\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "unresolved nested Prelude",
      with_prelude "anchor-ambiguous-text" 0 "module Nested: Unknown"
        "open Prelude.Nested\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known local open",
      with_prelude "anchor-ambiguous-text" 1 "let value: int"
        "let view = {open Prelude; <a href=\"/docs\"> {React.string(\"Click \
         here\")} </a>}" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
