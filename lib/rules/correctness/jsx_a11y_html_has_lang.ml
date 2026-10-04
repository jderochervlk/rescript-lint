let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/html-has-lang";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in

  issue "html-has-lang"
    (tag = "html" && empty_prop "lang" element)
    "Declare the document language with lang."
