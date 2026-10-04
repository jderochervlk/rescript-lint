let metadata =
  Rule_metadata.
    {
      id = "test/no-identical-title";
      category = Style;
      enabled_by_default = false;
    }

open Test_rule_support

let report_title emit previous registration =
  Option.iter
    (fun (title, location) ->
      let duplicate =
        List.exists
          (function
            | Registration earlier ->
                earlier.api.kind = registration.api.kind
                && Option.map fst earlier.title = Some title
            | _ -> false)
          previous
      in
      if duplicate then
        emit "test/no-identical-title"
          "This sibling test or suite repeats an earlier title." location)
    registration.title
