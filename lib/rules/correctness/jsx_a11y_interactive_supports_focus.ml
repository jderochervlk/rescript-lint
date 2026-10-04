let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/interactive-supports-focus";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  let exposed =
    visible element && M.bool_prop "contentEditable" element <> Some true
  in
  let interacts = any_prop handlers element in
  issue "interactive-supports-focus"
    (exposed && interacts && interactive_role element
    && M.focusable element = Some false)
    "Make this interactive role focusable."
