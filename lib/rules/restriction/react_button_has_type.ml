let metadata =
  Rule_metadata.
    {
      id = "react/button-has-type";
      category = Restriction;
      enabled_by_default = false;
    }

open React_dom_support

let inspect tag element =
  issue "button-has-type"
    (tag = "button" && M.absent "type_" element)
    "Declare this button's type_ to make form submission intentional."
