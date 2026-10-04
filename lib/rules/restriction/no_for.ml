let metadata =
  Rule_metadata.
    { id = "no-for"; category = Restriction; enabled_by_default = false }

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_for _ ->
      emit "no-for"
        "Prefer a collection operation or an explicit recursive function to \
         this loop."
        expression.pexp_loc
  | _ -> ()
