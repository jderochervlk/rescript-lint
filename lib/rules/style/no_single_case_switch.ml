let metadata =
  Rule_metadata.
    {
      id = "no-single-case-switch";
      category = Style;
      enabled_by_default = false;
    }

open Syntax_policy_support

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_match (_, [ case ]) when irrefutable case ->
      emit "no-single-case-switch"
        "Replace this irrefutable single-case switch with a binding or \
         sequence."
        expression.pexp_loc
  | _ -> ()
