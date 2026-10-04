let metadata =
  Rule_metadata.
    {
      id = "no-duplicate-condition";
      category = Correctness;
      enabled_by_default = true;
    }

open Control_flow_support

let report_duplicates ~source diagnostics expressions =
  let rec loop previous = function
    | [] -> ()
    | expression :: rest ->
        if List.exists (equivalent expression) previous then
          emit ~source diagnostics "no-duplicate-condition"
            "This condition duplicates an earlier condition in the same chain."
            expression;
        let previous =
          if stable expression then expression :: previous else []
        in
        loop previous rest
  in
  loop [] expressions

let report_switch_guards ~source diagnostics cases =
  let rec loop previous = function
    | [] -> ()
    | (case : Parsetree.case) :: rest ->
        let comparable = List.filter (same_pattern case) previous in
        let guards =
          List.filter_map (fun case -> case.Parsetree.pc_guard) comparable
          |> List.rev
        in
        let guards = guards @ Option.to_list case.pc_guard in
        report_duplicates ~source diagnostics guards;
        let previous =
          match case.pc_guard with
          | Some guard when stable guard -> case :: previous
          | _ -> []
        in
        loop previous rest
  in
  loop [] cases

let inspect ~source diagnostics (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse _ ->
      let branches, _ = if_chain expression in
      report_duplicates ~source diagnostics (List.map fst branches)
  | Pexp_match (_, cases) -> report_switch_guards ~source diagnostics cases
  | _ -> ()
