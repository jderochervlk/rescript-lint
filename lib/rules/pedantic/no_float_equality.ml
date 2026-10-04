let metadata =
  Rule_metadata.
    {
      id = "no-float-equality";
      category = Pedantic;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) left right =
  let left_type, right_type = (infer scope left, infer scope right) in
  if
    (left_type = Float || right_type = Float)
    && (not (literal left || literal right))
    && not (has_attribute "lint.exactFloat" expression.pexp_attributes)
  then
    report.emit "no-float-equality"
      "Exact equality of computed floats is fragile; choose a tolerance scaled \
       to the values and domain."
      expression.pexp_loc;
  if
    (left_type = Unknown || right_type = Unknown)
    && not (literal left || literal right)
  then
    report.boundary "no-float-equality"
      "Operand types are required to identify computed float equality."
      expression.pexp_loc
