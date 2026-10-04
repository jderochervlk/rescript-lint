let metadata =
  Rule_metadata.
    { id = "max-switch-cases"; category = Pedantic; enabled_by_default = false }

let inspect ~maximum emit (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_match (_, cases) when List.length cases > maximum ->
      emit "max-switch-cases"
        (Printf.sprintf
           "This switch has %d cases; the configured maximum is %d."
           (List.length cases) maximum)
        expression.pexp_loc
  | _ -> ()
