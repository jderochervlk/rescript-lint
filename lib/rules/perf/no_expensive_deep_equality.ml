let metadata =
  Rule_metadata.
    {
      id = "no-expensive-deep-equality";
      category = Perf;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let inspect report context scope (expression : Parsetree.expression) operator
    left right =
  let left_type, right_type = (infer scope left, infer scope right) in
  if
    List.mem operator [ "=="; "!=" ]
    && max (risk left_type) (risk right_type) >= context.deep_equality_threshold
  then
    report.emit "no-expensive-deep-equality"
      "This compound value comparison may traverse a large value graph; \
       compare the relevant fields explicitly."
      expression.pexp_loc;
  if
    List.mem operator [ "=="; "!=" ]
    && (left_type = Unknown || right_type = Unknown)
  then
    report.boundary "no-expensive-deep-equality"
      "Operand types are required to estimate deep-comparison risk."
      expression.pexp_loc
