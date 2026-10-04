let metadata =
  Rule_metadata.
    { id = "react/jsx-key"; category = Correctness; enabled_by_default = false }

open React_dom_support

let inspect ~emit element =
  if M.absent "key" element then
    emit "jsx-key" "Give each element in a rendered collection a stable key."
      element.M.location
