let metadata =
  Rule_metadata.
    {
      id = "no-constant-condition";
      category = Correctness;
      enabled_by_default = true;
    }

open Control_flow_support

let report_constant ~source diagnostics expression =
  Option.iter
    (fun result ->
      let value = string_of_bool (bool_of_truth result) in
      emit ~source diagnostics "no-constant-condition"
        ("This condition is always " ^ value ^ ".")
        expression)
    (truth expression)

let inspect ~source diagnostics (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse (condition, _, _) | Pexp_while (condition, _) ->
      report_constant ~source diagnostics condition
  | Pexp_match (_, cases) ->
      List.iter
        (report_constant ~source diagnostics)
        (List.filter_map (fun case -> case.Parsetree.pc_guard) cases)
  | _ -> ()
