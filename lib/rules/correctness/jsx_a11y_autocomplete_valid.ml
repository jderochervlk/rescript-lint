let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/autocomplete-valid";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in

  issue "autocomplete-valid"
    (List.mem tag [ "input"; "select"; "textarea" ]
    && Option.exists
         (fun text -> not (valid_autocomplete text))
         (M.string_prop "autoComplete" element))
    "Use a valid HTML autocomplete token sequence."
