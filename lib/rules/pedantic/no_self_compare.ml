let metadata =
  Rule_metadata.
    { id = "no-self-compare"; category = Pedantic; enabled_by_default = false }

open Semantic_model
open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) left right =
  let left_type = infer scope left in
  if same_value scope left right && is_stable_expression scope left then
    if left_type = Unknown then
      report.boundary "no-self-compare"
        "The value type is needed to distinguish an intentional float NaN test."
        expression.pexp_loc
    else
      report.emit "no-self-compare"
        (if left_type = Float then
           "This float is compared with itself; use an explicit NaN predicate \
            when testing NaN."
         else "This stable value is compared with itself.")
        expression.pexp_loc
