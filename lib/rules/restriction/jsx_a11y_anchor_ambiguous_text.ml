let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/anchor-ambiguous-text";
      category = Restriction;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let react_unshadowed = context.react_unshadowed in
  let tag = context.tag in
  let element = context.element in
  let ambiguous =
    match text_children ~react_unshadowed element.M.children with
    | Some text ->
        List.mem (normalize_words text)
          [ "click here"; "here"; "link"; "more"; "read more"; "learn more" ]
    | None -> false
  in
  issue "anchor-ambiguous-text"
    (tag = "a" && ambiguous && not (named_by_prop element))
    "Use link text that describes its destination."
