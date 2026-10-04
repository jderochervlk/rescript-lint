let metadata =
  Rule_metadata.
    { id = "no-debugger"; category = Correctness; enabled_by_default = true }

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_extension ({ txt = "debugger"; _ }, _) ->
      emit "no-debugger" "Remove this debugger expression." expression.pexp_loc
  | _ -> ()
