let metadata =
  Rule_metadata.
    { id = "no-nested-ternary"; category = Style; enabled_by_default = false }

open Syntax_policy_support

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse (condition, yes, Some no)
    when ternary expression
         && List.exists
              (fun child -> ternary (Semantic_model.unwrap child))
              [ condition; yes; no ] ->
      emit "no-nested-ternary" "Extract the nested ternary or use a switch."
        expression.pexp_loc
  | _ -> ()
