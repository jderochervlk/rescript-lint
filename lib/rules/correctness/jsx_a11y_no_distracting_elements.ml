let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-distracting-elements";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in

  issue "no-distracting-elements"
    (List.mem tag [ "marquee"; "blink" ])
    "Replace this distracting element with ordinary content."
