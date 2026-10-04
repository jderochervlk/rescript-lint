let metadata =
  Rule_metadata.
    {
      id = "test/no-disabled-tests";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit registration =
  if registration.api.todo then
    emit "test/no-disabled-tests" "Enable this disabled test or suite."
      registration.location;
  List.iter
    (fun (name, location) ->
      if name <> "only" then
        emit "test/no-disabled-tests" "Enable this disabled test or suite."
          location)
    registration.flags

let runtime_skip emit location =
  emit "test/no-disabled-tests" "Remove this runtime test skip." location
