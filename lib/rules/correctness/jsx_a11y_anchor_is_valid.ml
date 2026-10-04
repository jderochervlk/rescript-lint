let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/anchor-is-valid";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in

  issue "anchor-is-valid"
    (tag = "a" && invalid_anchor element)
    "Use a navigable href, or a button for an action."
