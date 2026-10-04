open Rescript_linter

let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ("empty file", check ~max_lines:0 "max-lines" 0 "");
    ( "lines",
      check ~max_lines:1
        ~expected_range:
          Diagnostic.
            {
              start = { line = 1; column = 1; byte_offset = 0 };
              finish = { line = 1; column = 1; byte_offset = 0 };
            }
        "max-lines" 1 "// one\nlet value = 1\n" );
    ("line boundary", check ~max_lines:2 "max-lines" 0 "// one\nlet value = 1\n");
    ("CRLF", check ~max_lines:1 "max-lines" 1 "// one\r\nlet value = 1\r\n");
    ( "last unterminated line",
      check ~max_lines:1 "max-lines" 1 "// one\nlet value = 1" );
    ( "signature lines",
      check ~kind:Interface ~max_lines:0 "max-lines" 1 "let value: int" );
  ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
