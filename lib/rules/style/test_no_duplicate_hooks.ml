let metadata =
  Rule_metadata.
    {
      id = "test/no-duplicate-hooks";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit previous hook location =
  if
    List.exists
      (function Hook (earlier, _, _) -> earlier = hook | _ -> false)
      previous
  then
    emit "test/no-duplicate-hooks" "Combine duplicate hooks in this suite."
      location
