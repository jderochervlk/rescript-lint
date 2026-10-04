let metadata =
  Rule_metadata.
    {
      id = "no-dynamic-code";
      category = Restriction;
      enabled_by_default = false;
    }

open Semantic_rule_support

let application report scope (expression : Parsetree.expression) funct =
  match api scope funct with
  | Some [ "Global"; ("eval" | "Function") ] ->
      report.emit "no-dynamic-code"
        "This resolved global API evaluates dynamically supplied JavaScript."
        expression.pexp_loc
  | _ -> ()

let inspect report (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_extension ({ txt = "raw" | "bs.raw" | "res.raw"; _ }, _) ->
      report.emit "no-dynamic-code"
        "Raw JavaScript bypasses the configured static-code boundary."
        expression.pexp_loc
  | _ -> ()
