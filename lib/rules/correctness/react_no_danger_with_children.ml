let metadata =
  Rule_metadata.
    {
      id = "react/no-danger-with-children";
      category = Correctness;
      enabled_by_default = false;
    }

open React_dom_support

let inspect _tag element =
  issue "no-danger-with-children"
    (M.present "dangerouslySetInnerHTML" element && has_children element)
    "Choose children or dangerouslySetInnerHTML, not both."
