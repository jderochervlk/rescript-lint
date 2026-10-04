let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/aria-unsupported-elements";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in
  issue "aria-unsupported-elements"
    (List.mem tag
       [ "base"; "head"; "link"; "meta"; "param"; "script"; "style"; "title" ]
    && (List.exists
          (fun (property : M.property) ->
            Option.is_some (M.aria_name property.name))
          element.M.props
       || M.present "role" element))
    "This metadata element does not support ARIA semantics."
