let metadata =
  Rule_metadata.
    {
      id = "no-identical-branches";
      category = Suspicious;
      enabled_by_default = true;
    }

open Control_flow_support

let report_identical ~source diagnostics expressions =
  let rec loop = function
    | previous :: (current :: _ as rest) ->
        if normalized previous = normalized current then
          emit ~source diagnostics "no-identical-branches"
            "This branch is identical to the preceding branch." current;
        loop rest
    | _ -> ()
  in
  loop expressions

let report_switch_bodies ~source diagnostics cases =
  let rec loop = function
    | previous :: (current :: _ as rest) ->
        if comparable_bodies previous current then
          report_identical ~source diagnostics
            [ previous.pc_rhs; current.pc_rhs ];
        loop rest
    | _ -> ()
  in
  loop cases

let inspect ~source diagnostics (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse _ ->
      let branches, otherwise = if_chain expression in
      report_identical ~source diagnostics
        (List.map snd branches @ Option.to_list otherwise)
  | Pexp_match (_, cases) -> report_switch_bodies ~source diagnostics cases
  | _ -> ()
