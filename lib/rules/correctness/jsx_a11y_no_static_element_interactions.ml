let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-static-element-interactions";
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
  issue "no-static-element-interactions"
    (exposed && inactive && interacts && lacks_role
    && M.implicit_role element = None)
    "Give this interactive element appropriate semantics."
