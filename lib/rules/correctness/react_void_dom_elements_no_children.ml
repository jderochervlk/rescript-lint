let metadata =
  Rule_metadata.
    {
      id = "react/void-dom-elements-no-children";
      category = Correctness;
      enabled_by_default = false;
    }

open React_dom_support

let void_tags =
  M.words
    "area base br col embed hr img input keygen link meta param source track \
     wbr"

let inspect tag element =
  issue "void-dom-elements-no-children"
    (List.mem tag void_tags
    && (has_children element || M.present "dangerouslySetInnerHTML" element))
    "Void DOM elements cannot have children or inner HTML."
