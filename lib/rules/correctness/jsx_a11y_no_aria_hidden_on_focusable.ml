let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-aria-hidden-on-focusable";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "no-aria-hidden-on-focusable"
    (M.bool_prop "ariaHidden" element = Some true
    && M.focusable element = Some true)
    "Do not hide a focusable element from the accessibility tree."
