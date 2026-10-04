let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-noninteractive-tabindex";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  let inactive = M.native_interactive element = Some false in
  issue "no-noninteractive-tabindex"
    (inactive
    && (M.absent "role" element || Option.is_some (M.explicit_role element))
    && (not (interactive_role element))
    && Option.exists (fun index -> index >= 0) (M.int_prop "tabIndex" element))
    "Avoid tab stops on noninteractive elements."
