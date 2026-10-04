let metadata =
  Rule_metadata.
    {
      id = "test/valid-title";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit registration =
  Option.iter
    (fun (title, location) ->
      if String.trim title = "" then
        emit "test/valid-title" "Give this test or suite a nonempty title."
          location)
    registration.title
