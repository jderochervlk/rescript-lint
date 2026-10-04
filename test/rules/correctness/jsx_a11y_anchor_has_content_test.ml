let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("empty anchor", yes "anchor-has-content" "<a href=\"/docs\" />");
    ( "empty React string",
      yes "anchor-has-content" "<a href=\"/docs\"> {React.string(\" \" )} </a>"
    );
    ( "hidden link content",
      yes "anchor-has-content"
        "<a href=\"/docs\"> <span ariaHidden=true> {React.string(\"Docs\")} \
         </span> </a>" );
    ( "named anchor",
      no "anchor-has-content" "<a href=\"/docs\" ariaLabel=\"Docs\" />" );
    ( "image content",
      no "anchor-has-content" "<a href=\"/docs\"> <img alt=\"Docs\" /> </a>" );
    ( "hidden anchor",
      no "anchor-has-content" "<a href=\"/docs\" ariaHidden=true />" );
    ( "custom child unknown content",
      no "anchor-has-content" "<a href=\"/docs\"> <Icon /> </a>" );
    ( "unit children empty",
      yes "anchor-has-content" "<a href=\"/docs\"> {()} </a>" );
    ( "hidden ancestor excludes content audit",
      no "anchor-has-content"
        "<div ariaHidden=true> <a href=\"/docs\" /> </div>" );
    ( "dynamic child label",
      no "anchor-has-content"
        "<a href=\"/docs\"> <span ariaLabel={label} /> </a>" );
    ( "dynamic image name",
      no "anchor-has-content" "<a href=\"/docs\"> <img alt={alt} /> </a>" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "labelled child",
        Jsx_rules_test_support.check "anchor-has-content" 0
          "let view = <a href=\"/\"><span ariaLabel=\"Destination\" /></a>" );
    ]
