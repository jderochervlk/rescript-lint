let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/img-redundant-alt";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in
  let redundant =
    match M.string_prop "alt" element with
    | Some text ->
        List.exists
          (fun word -> List.mem word [ "image"; "picture"; "photo" ])
          (M.words (normalize_words text))
    | None -> false
  in
  issue "img-redundant-alt"
    (tag = "img" && redundant)
    "Describe the image without redundant image, picture, or photo wording."
