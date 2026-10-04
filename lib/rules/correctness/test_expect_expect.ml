let metadata =
  Rule_metadata.
    {
      id = "test/expect-expect";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let report_missing_assertions emit events registration =
  if
    registration.api.kind = Test_scope.Test
    && registration.callback_known
    && (not registration.api.todo)
    && (not (List.exists (fun (name, _) -> name = "todo") registration.flags))
    && not
         (List.exists
            (fun event -> assertion_owner event = Some registration.key)
            events)
  then
    emit "test/expect-expect"
      "This test callback contains no recognized assertion."
      registration.location
