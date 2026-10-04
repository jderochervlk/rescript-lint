let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "noninteractive tab stop",
      yes "no-noninteractive-tabindex" "<div tabIndex=0 />" );
    ("native tab stop", no "no-noninteractive-tabindex" "<button tabIndex=0 />");
    ( "negative tabindex",
      no "no-noninteractive-tabindex" "<div tabIndex={-1} />" );
    ( "dynamic role tabindex unknown",
      no "no-noninteractive-tabindex" "<div role={role} tabIndex=0 />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
