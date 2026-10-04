let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/click-events-have-key-events";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  let inactive = M.native_interactive element = Some false in
  let exposed =
    visible element && M.bool_prop "contentEditable" element <> Some true
  in
  issue "click-events-have-key-events"
    (exposed && inactive
    && M.present "onClick" element
    && all_absent keyboard element)
    "Provide keyboard activation alongside this click handler."
