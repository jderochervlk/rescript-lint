let metadata =
  Rule_metadata.
    {
      id = "test/no-focused-tests";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit registration =
  if registration.api.focused then
    emit "test/no-focused-tests" "Remove this focused test or suite."
      registration.location;
  List.iter
    (fun (name, location) ->
      if name = "only" then
        emit "test/no-focused-tests" "Remove this focused test or suite."
          location)
    registration.flags
