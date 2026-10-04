open Rescript_linter

let checks_project_rules_test_support =
  let open Project_rules_test_support in
  Rule_test_runner.of_bools
    [
      ( "license missing",
        check "require-license-header" Project_options.default
          (source "license.res" "let x = 1")
          found );
      ( "license exact",
        check "require-license-header" Project_options.default
          (source "license.res" "// SPDX-License-Identifier: MIT\nlet x = 1")
          clean );
      ( "license mismatch",
        check "require-license-header" Project_options.default
          (source "license.res"
             "// SPDX-License-Identifier: Apache-2.0\nlet x = 1")
          found );
      ( "license block",
        check "require-license-header" Project_options.default
          (source "license.res"
             "/*\n * SPDX-License-Identifier: MIT\n */\nlet x = 1")
          clean );
      ( "license in string",
        check "require-license-header" Project_options.default
          (source "license.res" "let x = \"SPDX-License-Identifier: MIT\"")
          found );
      ( "license after code",
        check "require-license-header" Project_options.default
          (source "license.res" "let x = 1\n// SPDX-License-Identifier: MIT")
          found );
    ]

let () = Rule_test_runner.run checks_project_rules_test_support
