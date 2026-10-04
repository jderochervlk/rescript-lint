let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ( "invalid autocomplete",
      yes "autocomplete-valid" "<input autoComplete=\"electronic-mail\" />" );
    ( "valid autocomplete",
      no "autocomplete-valid" "<input autoComplete=\"email\" />" );
    ( "qualified autocomplete",
      no "autocomplete-valid"
        "<input autoComplete=\"section-account shipping home tel webauthn\" />"
    );
    ( "autocomplete off",
      no "autocomplete-valid" "<input autoComplete=\"off\" />" );
    ( "autocomplete contact mismatch",
      yes "autocomplete-valid" "<input autoComplete=\"home name\" />" );
    ( "autocomplete wrong order",
      yes "autocomplete-valid" "<input autoComplete=\"email shipping\" />" );
    ( "autocomplete invalid section",
      yes "autocomplete-valid" "<input autoComplete=\"section- name\" />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
