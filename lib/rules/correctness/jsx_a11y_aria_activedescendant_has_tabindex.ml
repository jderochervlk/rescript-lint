let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/aria-activedescendant-has-tabindex";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "aria-activedescendant-has-tabindex"
    (M.present "ariaActivedescendant" element
    && M.focusable element = Some false)
    "Make the active-descendant owner focusable."
