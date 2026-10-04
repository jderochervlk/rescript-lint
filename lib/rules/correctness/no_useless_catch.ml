let metadata =
  Rule_metadata.
    {
      id = "no-useless-catch";
      category = Correctness;
      enabled_by_default = true;
    }

open Exception_rule_support

let inspect emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_try (_, cases)
    when cases <> [] && List.for_all (useless_case scope) cases ->
      emit "no-useless-catch" "This catch only rethrows the original exception."
        expression.pexp_loc
  | _ -> ()
