let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/heading-has-content";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let react_unshadowed = context.react_unshadowed in
  let tag = context.tag in
  let element = context.element in
  let empty = empty_label ~react_unshadowed element in
  issue "heading-has-content"
    (List.mem tag [ "h1"; "h2"; "h3"; "h4"; "h5"; "h6" ]
    && empty && visible element)
    "Give this heading accessible content."
