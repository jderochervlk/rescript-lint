let metadata =
  Rule_metadata.
    {
      id = "no-record-mutation";
      category = Restriction;
      enabled_by_default = false;
    }

let inspect emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_setfield _ ->
      emit "no-record-mutation"
        "Prefer constructing an updated record to assigning a field."
        expression.pexp_loc
  | _ -> ()
