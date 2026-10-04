let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-noninteractive-element-interactions";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  let exposed =
    visible element && M.bool_prop "contentEditable" element <> Some true
  in
  let inactive = M.native_interactive element = Some false in
  let interacts = any_prop handlers element in
  let lacks_role = M.absent "role" element in
  issue "no-noninteractive-element-interactions"
    (exposed && inactive && interacts && lacks_role)
    "Use an interactive element for these interaction handlers."
