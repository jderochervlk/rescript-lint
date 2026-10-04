let metadata =
  Rule_metadata.
    {
      id = "no-constant-binary-expression";
      category = Correctness;
      enabled_by_default = true;
    }

open Control_flow_support

let report_constant_binary ~source diagnostics expression =
  match (binary expression, truth expression) with
  | Some _, Some result ->
      let value = string_of_bool (bool_of_truth result) in
      emit ~source diagnostics "no-constant-binary-expression"
        ("This binary expression always evaluates to " ^ value ^ ".")
        expression
  | _ -> ()

let inspect = report_constant_binary
