let metadata =
  Rule_metadata.
    { id = "max-nesting"; category = Pedantic; enabled_by_default = false }

open Policy_rule_support

let report_nesting ~emit limits depth expression =
  if depth = limits.max_nesting + 1 then
    emit "max-nesting"
      (Printf.sprintf
         "Control-flow nesting exceeds the configured maximum of %d."
         limits.max_nesting)
      expression.Parsetree.pexp_loc
