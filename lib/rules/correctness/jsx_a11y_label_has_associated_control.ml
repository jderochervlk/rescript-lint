let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/label-has-associated-control";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let elements = context.elements in
  let tag = context.tag in
  let element = context.element in
  let nested_control =
    tag = "label"
    && List.exists
         (fun child -> contains element child && labelable child)
         elements
  in
  issue "label-has-associated-control"
    (tag = "label"
    && empty_prop "htmlFor" element
    && (not nested_control) && not element.M.spread)
    "Associate this label using htmlFor or a nested control."
