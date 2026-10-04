let metadata =
  Rule_metadata.
    {
      id = "no-catch-all-exception";
      category = Restriction;
      enabled_by_default = false;
    }

open Exception_rule_support

let inspect_catch emit scope pattern (case : Parsetree.case) =
  if
    Option.is_none case.pc_guard
    && catch_all pattern
    && not (rethrows scope case.pc_lhs case.pc_rhs)
  then
    emit "no-catch-all-exception"
      "Handle specific exceptions instead of swallowing every exception."
      pattern.ppat_loc

let rec inspect_exception_pattern emit scope case pattern =
  match pattern.Parsetree.ppat_desc with
  | Ppat_exception inner -> inspect_catch emit scope inner case
  | Ppat_or (left, right) ->
      inspect_exception_pattern emit scope case left;
      inspect_exception_pattern emit scope case right
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) ->
      inspect_exception_pattern emit scope case inner
  | _ -> ()

let inspect emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_try (_, cases) ->
      List.iter
        (fun (case : Parsetree.case) ->
          inspect_catch emit scope case.pc_lhs case)
        cases
  | Pexp_match (_, cases) ->
      List.iter
        (fun (case : Parsetree.case) ->
          inspect_exception_pattern emit scope case case.pc_lhs)
        cases
  | _ -> ()
