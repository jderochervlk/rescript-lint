let metadata =
  Rule_metadata.
    {
      id = "test/max-nested-describe";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit maximum registration =
  if
    registration.context.active
    && registration.api.kind = Test_scope.Describe
    && registration.context.depth + 1 > maximum
  then
    emit "test/max-nested-describe"
      (Printf.sprintf "Suite nesting exceeds the configured maximum of %d."
         maximum)
      registration.location
