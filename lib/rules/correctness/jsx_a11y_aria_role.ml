let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/aria-role";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  issue "aria-role"
    (Option.exists
       (fun _ -> M.explicit_role element = None)
       (M.string_prop "role" element))
    "Use a concrete supported ARIA role."
