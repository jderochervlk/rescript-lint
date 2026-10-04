let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-access-key";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "no-access-key"
    (M.present "accessKey" element)
    "Avoid accessKey because it conflicts with assistive keyboard shortcuts."
