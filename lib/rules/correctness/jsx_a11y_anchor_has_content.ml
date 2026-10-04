let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/anchor-has-content";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let react_unshadowed = context.react_unshadowed in
  let tag = context.tag in
  let element = context.element in
  let empty = empty_label ~react_unshadowed element in
  issue "anchor-has-content"
    (tag = "a" && empty && visible element)
    "Give this link accessible content."
