let metadata =
  Rule_metadata.
    {
      id = "no-partial-function";
      category = Correctness;
      enabled_by_default = false;
    }

open Semantic_rule_support

let inspect report scope (expression : Parsetree.expression) funct =
  Option.iter
    (fun name ->
      Option.iter
        (fun alternative ->
          report.emit "no-partial-function"
            ("This API can fail on missing input; use " ^ alternative ^ ".")
            expression.pexp_loc)
        (partial_alternative name))
    (api scope funct)
