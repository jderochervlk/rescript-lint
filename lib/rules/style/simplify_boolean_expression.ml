let metadata =
  Rule_metadata.
    {
      id = "simplify-boolean-expression";
      category = Style;
      enabled_by_default = false;
    }

open Expression_rule_support

let simplify_boolean ~source (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse (_, left, Some right) -> opposite_booleans left right
  | Pexp_match (_, [ left; right ]) -> boolean_switch left right
  | Pexp_apply _ ->
      Option.fold ~none:false ~some:boolean_binary (binary ~source expression)
      || Option.fold ~none:false
           ~some:(fun inner -> negated ~source inner <> None)
           (negated ~source expression)
  | _ -> false

let inspect ~source expression =
  if simplify_boolean ~source expression then
    Some
      ( "simplify-boolean-expression",
        "This boolean expression can be simplified." )
  else None
