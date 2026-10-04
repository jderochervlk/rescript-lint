let metadata =
  Rule_metadata.
    {
      id = "test/require-top-level-describe";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit registration =
  if
    registration.context.active
    && registration.api.kind = Test_scope.Test
    && registration.context.depth = 0
  then
    emit "test/require-top-level-describe"
      "Place this test inside a top-level describe suite." registration.location
