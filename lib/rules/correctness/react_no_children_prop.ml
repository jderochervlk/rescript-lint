let metadata =
  Rule_metadata.
    {
      id = "react/no-children-prop";
      category = Correctness;
      enabled_by_default = false;
    }

open React_dom_support

let inspect element =
  issue "no-children-prop"
    (M.present "children" element)
    "Pass children between the JSX opening and closing tags."
