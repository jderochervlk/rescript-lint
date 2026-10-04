open Rescript_linter

let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("image alt missing", yes "alt-text" "<img src=\"photo.png\" />");
    ("decorative alt", no "alt-text" "<img alt=\"\" />");
    ("named image", no "alt-text" "<img ariaLabel=\"Profile\" />");
    ("area alternative", yes "alt-text" "<area href=\"/help\" />");
    ("image input alternative", yes "alt-text" "<input type_=\"image\" />");
    ( "object fallback",
      no "alt-text" "<object> {React.string(\"Document\")} </object>" );
    ("empty object", yes "alt-text" "<object />");
    ("ordinary input", no "alt-text" "<input type_=\"text\" />");
    ("spread alt unknown", no "alt-text" "<img {...props} />");
    ("optional alt unknown", no "alt-text" "<img alt=?alt />");
    ("custom component exempt", no "alt-text" "<Image />");
    ("custom element exempt", no "alt-text" "<custom-image />");
    ( "interface exempt",
      check ~kind:Source.Interface "alt-text" 0 "let image: Jsx.element" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
