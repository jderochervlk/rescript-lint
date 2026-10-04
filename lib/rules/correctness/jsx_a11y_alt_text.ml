let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/alt-text";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in
  let missing_alt = empty_prop "alt" element && not (named_by_prop element) in
  let required =
    match tag with
    | "img" -> M.absent "alt" element && not (named_by_prop element)
    | "area" -> missing_alt
    | "input" -> M.string_prop "type_" element = Some "image" && missing_alt
    | "object" -> missing_alt && M.children_content element = M.Empty
    | _ -> false
  in
  issue "alt-text" required "Provide a text alternative for this element."
