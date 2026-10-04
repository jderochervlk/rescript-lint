let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/control-has-associated-label";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let react_unshadowed = context.react_unshadowed in
  let elements = context.elements in
  let tag = context.tag in
  let element = context.element in
  let control =
    List.mem tag [ "button"; "input"; "select"; "textarea" ]
    && not
         (tag = "input"
         && List.mem
              (M.string_prop "type_" element)
              [
                Some "hidden";
                Some "submit";
                Some "reset";
                Some "button";
                Some "image";
              ])
  in
  issue "control-has-associated-label"
    (control && visible element
    && empty_label ~react_unshadowed element
    && not (associated_label ~react_unshadowed elements element))
    "Associate this control with a label or accessible name."
