let metadata =
  Rule_metadata.
    { id = "prefer-if"; category = Style; enabled_by_default = false }

open Syntax_policy_support

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_match (_, [ first; second ]) when boolean_cases first second ->
      emit "prefer-if"
        "Prefer an if expression for this two-case boolean switch."
        expression.pexp_loc
  | _ -> ()
