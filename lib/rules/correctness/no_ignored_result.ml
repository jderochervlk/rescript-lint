let metadata =
  Rule_metadata.
    {
      id = "no-ignored-result";
      category = Correctness;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) value =
  match infer scope value with
  | Result _ ->
      report.emit "no-ignored-result"
        "Handle the Ok and Error cases instead of discarding this result."
        expression.pexp_loc
  | Unknown ->
      report.boundary "no-ignored-result"
        "The discarded expression's result type is needed to determine whether \
         it is a must-use result."
        expression.pexp_loc
  | _ -> ()
