let metadata =
  Rule_metadata.
    {
      id = "no-empty-function";
      category = Restriction;
      enabled_by_default = false;
    }

open Policy_rule_support

let inspect ~emit arity (expression : Parsetree.expression) =
  if empty_body (function_body arity expression) then
    emit "no-empty-function"
      "This function has an empty body; annotate an intentional no-op with a \
       unit return type."
      expression.pexp_loc
