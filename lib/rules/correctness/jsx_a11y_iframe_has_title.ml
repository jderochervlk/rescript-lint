let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/iframe-has-title";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in

  issue "iframe-has-title"
    (tag = "iframe" && empty_prop "title" element)
    "Give this frame a descriptive title."
