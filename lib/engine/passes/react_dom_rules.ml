open React_dom_support

let rule_ids =
  [
    React_jsx_key.metadata.id;
    React_no_array_index_key.metadata.id;
    React_no_children_prop.metadata.id;
    React_no_danger_with_children.metadata.id;
    React_void_dom_elements_no_children.metadata.id;
    React_button_has_type.metadata.id;
    React_jsx_no_target_blank.metadata.id;
    React_iframe_missing_sandbox.metadata.id;
  ]

let dom_issues tag element =
  React_no_danger_with_children.inspect tag element
  @ React_void_dom_elements_no_children.inspect tag element
  @ React_button_has_type.inspect tag element
  @ React_jsx_no_target_blank.inspect tag element
  @ React_iframe_missing_sandbox.inspect tag element

let element_issues element =
  React_no_children_prop.inspect element
  @ Option.fold ~none:[]
      ~some:(fun tag -> dom_issues tag element)
      (M.intrinsic_tag element)

let inspect_key ~emit index element =
  React_jsx_key.inspect ~emit element;
  React_no_array_index_key.inspect ~emit index element

let rec rendered ~emit index (expression : Parsetree.expression) =
  match M.of_expression expression with
  | Some element -> inspect_key ~emit index element
  | None -> rendered_expression ~emit index expression

and rendered_expression ~emit index (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_let (_, bindings, body) ->
      let index =
        List.fold_left
          (fun index binding -> without_pattern index binding.Parsetree.pvb_pat)
          index bindings
      in
      rendered ~emit index body
  | Pexp_sequence (_, body) | Pexp_constraint (body, _) ->
      rendered ~emit index body
  | Pexp_ifthenelse (_, yes, no) ->
      rendered ~emit index yes;
      Option.iter (rendered ~emit index) no
  | Pexp_match (_, cases) | Pexp_try (_, cases) ->
      List.iter
        (fun case ->
          rendered ~emit
            (without_pattern index case.Parsetree.pc_lhs)
            case.pc_rhs)
        cases
  | Pexp_array values -> List.iter (rendered ~emit index) values
  | _ -> ()

let inspect_collection ~emit ~int_unshadowed = function
  | None -> ()
  | Some (indexed, collection, callback) ->
      Option.iter
        (fun (patterns, body) ->
          let index =
            match (indexed, patterns) with
            | (Second, [ _; index ] | First, [ index; _ ])
              when (not (static_collection collection)) && int_unshadowed ->
                pattern_name index
            | _ -> None
          in
          rendered ~emit index body)
        (function_parts callback)

let collection_issues ~module_signatures ~source tree =
  let diagnostics = ref [] in
  let emit name message location =
    diagnostics :=
      M.emit ~source ("react/" ^ name) message location :: !diagnostics
  in
  let array_unshadowed = M.unshadowed_module ~module_signatures "Array" tree in
  let list_unshadowed = M.unshadowed_module ~module_signatures "List" tree in
  let belt_unshadowed = M.unshadowed_module ~module_signatures "Belt" tree in
  let int_unshadowed = M.unshadowed_module ~module_signatures "Int" tree in
  let visitor =
    {
      Ast_iterator.default_iterator with
      expr =
        (fun iterator expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_array values -> List.iter (rendered ~emit None) values
          | _ -> ());
          Option.iter
            (fun (funct, args) ->
              collection_call ~array_unshadowed ~list_unshadowed
                ~belt_unshadowed funct args
              |> inspect_collection ~emit ~int_unshadowed)
            (call_parts expression);
          Ast_iterator.default_iterator.expr iterator expression);
      attribute = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  List.rev !diagnostics

let deduplicate diagnostics =
  List.fold_left
    (fun found (diagnostic : Diagnostic.t) ->
      if
        List.exists
          (fun (previous : Diagnostic.t) ->
            previous.rule = diagnostic.rule && previous.range = diagnostic.range)
          found
      then found
      else diagnostic :: found)
    [] diagnostics
  |> List.rev

let check ?(module_signatures = []) ~source tree =
  let elements = M.elements tree in
  let diagnostics =
    List.concat_map
      (fun element ->
        element_issues element
        |> List.map (fun (name, message) ->
            M.emit ~source ("react/" ^ name) message element.M.location))
      elements
  in
  diagnostics @ collection_issues ~module_signatures ~source tree
  |> Source_range.sort |> deduplicate
