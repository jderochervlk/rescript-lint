let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/media-has-caption";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let media_caption_checks elements element =
  let descendants = List.filter (contains element) elements in
  let track =
    List.exists
      (fun child ->
        M.intrinsic_tag child = Some "track"
        && M.string_prop "kind" child = Some "captions")
      descendants
  in
  let uncertain =
    List.exists
      (fun child ->
        M.intrinsic_tag child = None
        || child.M.spread
        || M.intrinsic_tag child = Some "track"
           && (not (M.absent "kind" child))
           && M.string_prop "kind" child = None)
      descendants
    || List.exists
         (fun child -> M.of_expression child = None)
         element.M.children
  in
  issue "media-has-caption"
    (M.bool_prop "muted" element <> Some true
    && visible element && (not track) && (not uncertain) && not element.spread)
    "Provide a captions track for this media."

let inspect (context : context) =
  if List.mem context.tag [ "audio"; "video" ] then
    media_caption_checks context.elements context.element
  else []
