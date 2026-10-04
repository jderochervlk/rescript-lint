let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("invalid language name", yes "lang" "<p lang=\"english\" />");
    ("language tag", no "lang" "<p lang=\"en-US\" />");
    ("script language tag", no "lang" "<p lang=\"zh-Hant-TW\" />");
    ("private language", no "lang" "<p lang=\"x-custom\" />");
    ("incomplete extension", yes "lang" "<p lang=\"en-u\" />");
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
