let metadata =
  Rule_metadata.
    {
      id = "no-negated-condition";
      category = Pedantic;
      enabled_by_default = false;
    }

open Syntax_policy_support

let inspect ~source emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse (condition, _, Some _) when negated ~source condition ->
      emit "no-negated-condition"
        "Prefer a positive condition and exchange the branches."
        expression.pexp_loc
  | _ -> ()
