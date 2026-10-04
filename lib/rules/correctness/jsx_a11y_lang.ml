let metadata =
  Rule_metadata.
    { id = "jsx-a11y/lang"; category = Correctness; enabled_by_default = false }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "lang"
    (Option.exists
       (fun text -> not (valid_language text))
       (M.string_prop "lang" element))
    "Use a valid language tag, such as en or en-US."
