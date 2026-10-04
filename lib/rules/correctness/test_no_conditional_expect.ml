let metadata =
  Rule_metadata.
    {
      id = "test/no-conditional-expect";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let nested_assertion events location expression context =
  List.exists
    (function
      | Assertion (inner, _, nested) ->
          nested.test = context.test
          && inner.loc_start.pos_cnum <> location.Location.loc_start.pos_cnum
          && inner.loc_start.pos_cnum >= expression.Location.loc_start.pos_cnum
          && inner.loc_end.pos_cnum <= expression.loc_end.pos_cnum
      | _ -> false)
    events

let inspect emit events location expression context =
  if not (nested_assertion events location expression context) then
    emit "test/no-conditional-expect"
      "Run this assertion unconditionally within the test." location
