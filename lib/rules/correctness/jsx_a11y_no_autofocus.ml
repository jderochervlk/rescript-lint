let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-autofocus";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "no-autofocus"
    (M.bool_prop "autoFocus" element = Some true)
    "Avoid moving focus automatically."
