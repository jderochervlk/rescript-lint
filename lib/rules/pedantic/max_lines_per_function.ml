let metadata =
  Rule_metadata.
    {
      id = "max-lines-per-function";
      category = Pedantic;
      enabled_by_default = false;
    }

open Policy_rule_support

let inspect ~emit maximum (expression : Parsetree.expression) =
  let location = expression.pexp_loc in
  let lines = location.loc_end.pos_lnum - location.loc_start.pos_lnum + 1 in
  report_limit ~emit "max-lines-per-function" "function's physical line span"
    maximum lines location
