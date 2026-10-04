let metadata =
  Rule_metadata.
    {
      id = "no-floating-promise";
      category = Correctness;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) value =
  match infer scope value with
  | Promise _ ->
      report.emit "no-floating-promise"
        "Handle, return, or await this promise instead of explicitly \
         discarding it."
        expression.pexp_loc
  | Unknown ->
      report.boundary "no-floating-promise"
        "The discarded expression's result type is needed to determine whether \
         it is a promise."
        expression.pexp_loc
  | _ -> ()
