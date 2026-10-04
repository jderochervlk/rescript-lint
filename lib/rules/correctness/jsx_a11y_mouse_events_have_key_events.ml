let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/mouse-events-have-key-events";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in

  issue "mouse-events-have-key-events"
    (any_prop [ "onMouseOver"; "onMouseEnter" ] element
     && M.absent "onFocus" element
    || any_prop [ "onMouseOut"; "onMouseLeave" ] element
       && M.absent "onBlur" element)
    "Pair mouse enter/leave handlers with focus/blur handlers."
