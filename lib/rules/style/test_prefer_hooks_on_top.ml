let metadata =
  Rule_metadata.
    {
      id = "test/prefer-hooks-on-top";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit previous _hook location =
  if List.exists (function Registration _ -> true | _ -> false) previous then
    emit "test/prefer-hooks-on-top"
      "Declare hooks before this suite's tests and nested suites." location
