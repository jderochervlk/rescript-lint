let metadata =
  Rule_metadata.
    { id = "max-params"; category = Style; enabled_by_default = false }

open Policy_rule_support

let inspect ~emit maximum arity pattern (expression : Parsetree.expression) =
  report_limit ~emit "max-params" "function's parameter list" maximum
    (parameter_count arity pattern)
    expression.pexp_loc
