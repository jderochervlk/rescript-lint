let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/scope";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in

  issue "scope"
    (tag <> "th" && M.present "scope" element)
    "Use scope only on table header cells."
