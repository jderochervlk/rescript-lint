let metadata =
  Rule_metadata.
    {
      id = "react/iframe-missing-sandbox";
      category = Suspicious;
      enabled_by_default = false;
    }

open React_dom_support

let inspect tag element =
  issue "iframe-missing-sandbox"
    (tag = "iframe" && M.absent "sandbox" element)
    "Declare an iframe sandbox and grant only the capabilities it needs."
