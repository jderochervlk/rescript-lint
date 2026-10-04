let metadata =
  Rule_metadata.
    {
      id = "no-unnecessary-template";
      category = Style;
      enabled_by_default = false;
    }

open Syntax_policy_support

let inspect ~source emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_string (_, Some "js"))
    when attribute "res.template" expression.pexp_attributes
         && complete_template ~source expression
         && not (attribute "res.taggedTemplate" expression.pexp_attributes) ->
      emit "no-unnecessary-template"
        "Prefer an ordinary string when no interpolation is needed."
        expression.pexp_loc
  | _ -> ()
