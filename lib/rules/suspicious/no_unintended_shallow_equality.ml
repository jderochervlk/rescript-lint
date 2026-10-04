let metadata =
  Rule_metadata.
    {
      id = "no-unintended-shallow-equality";
      category = Suspicious;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) operator left right
    =
  let left_type, right_type = (infer scope left, infer scope right) in
  if
    List.mem operator [ "==="; "!==" ]
    && not (has_attribute "lint.identity" expression.pexp_attributes)
  then
    if
      (is_compound_type left_type && not (literal left))
      || (is_compound_type right_type && not (literal right))
    then
      report.emit "no-unintended-shallow-equality"
        "This comparison tests compound value identity; use value equality or \
         annotate intentional identity with @lint.identity."
        expression.pexp_loc
    else if left_type = Unknown || right_type = Unknown then
      report.boundary "no-unintended-shallow-equality"
        "Operand types are required to distinguish identity from primitive \
         equality."
        expression.pexp_loc
