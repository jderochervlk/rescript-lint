let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/tabindex-no-positive";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "tabindex-no-positive"
    (Option.exists (fun value -> value > 0) (M.int_prop "tabIndex" element))
    "Use natural focus order instead of a positive tabIndex."
