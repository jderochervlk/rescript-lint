let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "blank external unsafe",
      yes "jsx-no-target-blank"
        "<a href=\"https://example.com\" target=\"_blank\" />" );
    ( "blank dynamic URL unsafe",
      yes "jsx-no-target-blank" "<a href={externalUrl} target=\"_blank\" />" );
    ( "blank protocol relative unsafe",
      yes "jsx-no-target-blank" "<a href=\"//example.com\" target=\"_blank\" />"
    );
    ( "blank noopener safe",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"noopener\" />" );
    ( "blank noreferrer safe",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"noreferrer\" />" );
    ( "blank unrelated rel unsafe",
      yes "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"nofollow\" />" );
    ( "blank dynamic rel unknown",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel={relation} />" );
    ( "blank internal URL",
      no "jsx-no-target-blank" "<a href=\"/docs\" target=\"_blank\" />" );
    ( "regular target",
      no "jsx-no-target-blank" "<a href={externalUrl} target=\"_self\" />" );
    ("missing href", no "jsx-no-target-blank" "<a target=\"_blank\" />");
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
