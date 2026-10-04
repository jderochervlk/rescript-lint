let metadata =
  Rule_metadata.
    {
      id = "prefer-standard-combinator";
      category = Style;
      enabled_by_default = false;
    }

open Semantic_model
open Recursion_rule_support

let list_pattern (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_construct ({ txt = Lident "[]"; _ }, None) -> Some None
  | Ppat_construct
      ( { txt = Lident "::"; _ },
        Some { ppat_desc = Ppat_tuple [ head; tail ]; _ } ) ->
      Some (Some (head, tail))
  | _ -> None

let list_expression expression =
  match (unwrap expression).pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> Some None
  | Pexp_construct
      ( { txt = Lident "::"; _ },
        Some { pexp_desc = Pexp_tuple [ head; tail ]; _ } ) ->
      Some (Some (head, tail))
  | _ -> None

let rec manual_map ~emit scope (binding : Parsetree.value_binding) =
  let parameters, body = function_parts binding.pvb_expr in
  match
    (pattern_name binding.pvb_pat, parameters, body.Parsetree.pexp_desc)
  with
  | ( Some name,
      [ (_, parameter) ],
      Pexp_match (subject, [ empty_case; cons_case ]) ) ->
      let nested = parameter_scope scope parameters in
      let parameter_id =
        Option.bind (pattern_name parameter) (fun name ->
            Option.map
              (fun value -> value.identity)
              (Names.find_opt name nested.values))
      in
      if
        reference_identity nested subject = parameter_id
        && parameter_id <> None && empty_case.pc_guard = None
        && cons_case.pc_guard = None
        && list_pattern empty_case.pc_lhs = Some None
        && list_expression empty_case.pc_rhs = Some None
      then manual_map_cons ~emit scope nested name binding.pvb_loc cons_case
  | _ -> ()

and manual_map_cons ~emit outer scope name location (case : Parsetree.case) =
  match (list_pattern case.pc_lhs, list_expression case.pc_rhs) with
  | Some (Some (head_pattern, tail_pattern)), Some (Some (mapped, rest)) -> (
      let nested = bind_pattern scope (List Unknown) case.pc_lhs in
      let callee =
        Option.map
          (fun value -> value.identity)
          (Names.find_opt name outer.values)
      in
      let tail =
        Option.bind (pattern_name tail_pattern) (fun name ->
            Option.map
              (fun value -> value.identity)
              (Names.find_opt name nested.values))
      in
      match rest.pexp_desc with
      | Pexp_apply { funct; args = [ (Nolabel, argument) ]; partial = false; _ }
        when reference_identity nested funct = callee
             && callee <> None
             && reference_identity nested argument = tail
             && tail <> None && pure nested mapped ->
          let head =
            Option.bind (pattern_name head_pattern) (fun name ->
                Option.map
                  (fun value -> value.identity)
                  (Names.find_opt name nested.values))
          in
          let uses_tail = ref false and uses_head = ref false in
          inspect_body nested mapped (fun current expression ->
              let id = reference_identity current expression in
              if id = tail then uses_tail := true;
              if id = head then uses_head := true);
          if !uses_head && not !uses_tail then
            emit "prefer-standard-combinator"
              "This pure list recursion has List.map semantics; use List.map \
               with the element transformation."
              location
      | _ -> ())
  | _ -> ()
