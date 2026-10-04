let metadata =
  Rule_metadata.
    {
      id = "test/prefer-hooks-in-order";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit previous hook location =
  if
    List.exists
      (function
        | Hook (earlier, _, _) -> hook_rank earlier > hook_rank hook
        | _ -> false)
      previous
  then
    emit "test/prefer-hooks-in-order"
      "Order hooks as beforeAll, beforeEach, afterEach, afterAll." location
