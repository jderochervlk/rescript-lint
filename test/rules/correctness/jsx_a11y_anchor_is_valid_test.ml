let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "placeholder href",
      yes "anchor-is-valid" "<a href=\"#\"> {React.string(\"Docs\")} </a>" );
    ( "javascript href",
      yes "anchor-is-valid" "<a href=\"javascript:void(0)\" />" );
    ("action anchor", yes "anchor-is-valid" "<a onClick={_ => action()} />");
    ("fragment href", no "anchor-is-valid" "<a href=\"#details\" />");
    ("dynamic href", no "anchor-is-valid" "<a href={destination} />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
