let metadata =
  Rule_metadata.
    { id = "no-empty-loop"; category = Suspicious; enabled_by_default = false }

open Syntax_policy_support

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | (Pexp_while (_, body) | Pexp_for (_, _, _, _, body)) when unit_body body ->
      emit "no-empty-loop" "This loop has an empty body." expression.pexp_loc
  | _ -> ()
