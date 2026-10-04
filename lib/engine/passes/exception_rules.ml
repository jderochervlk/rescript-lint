open Exception_rule_support

let inspect emit scope expression =
  No_debugger.inspect emit expression;
  No_useless_catch.inspect emit scope expression;
  No_catch_all_exception.inspect emit scope expression

let rec iterator emit scope : Ast_iterator.iterator =
  let default = Ast_iterator.default_iterator in
  {
    default with
    expr = (fun _ expression -> visit emit scope expression);
    structure = (fun _ items -> structure emit scope items);
    case =
      (fun _ case ->
        let nested = iterator emit (bind_pattern scope case.pc_lhs) in
        default.case nested case);
    module_expr =
      (fun self expression ->
        match expression.Parsetree.pmod_desc with
        | Pmod_functor (name, parameter, body) ->
            Option.iter (self.module_type self) parameter;
            let nested = iterator emit (Names.add name.txt scope) in
            nested.module_expr nested body
        | _ -> default.module_expr self expression);
    attribute = (fun _ _ -> ());
    attributes = (fun _ _ -> ());
  }

and visit emit scope expression =
  inspect emit scope expression;
  match expression.Parsetree.pexp_desc with
  | Pexp_let (recursive, bindings, body) ->
      let after = bind_bindings scope bindings in
      let inside = if recursive = Asttypes.Recursive then after else scope in
      List.iter
        (fun binding -> visit emit inside binding.Parsetree.pvb_expr)
        bindings;
      visit emit after body
  | Pexp_fun { default; lhs; rhs; _ } ->
      Option.iter (visit emit scope) default;
      visit emit (bind_pattern scope lhs) rhs
  | Pexp_open (_, _, body) -> visit emit (opaque scope) body
  | _ -> visit_scoped emit scope expression

and visit_scoped emit scope expression =
  let visitor = iterator emit scope in
  match expression.Parsetree.pexp_desc with
  | Pexp_letmodule (name, binding, body) ->
      visitor.module_expr visitor binding;
      visit emit (Names.add name.txt scope) body
  | Pexp_for (pattern, first, last, _, body) ->
      visit emit scope first;
      visit emit scope last;
      visit emit (bind_pattern scope pattern) body
  | _ -> Ast_iterator.default_iterator.expr visitor expression

and structure emit scope = function
  | [] -> ()
  | item :: rest ->
      let inside, after = structure_scopes scope item in
      let visitor = iterator emit inside in
      visitor.structure_item visitor item;
      structure emit after rest

and structure_scopes scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (recursive, bindings) ->
      let after = bind_bindings scope bindings in
      ((if recursive = Asttypes.Recursive then after else scope), after)
  | Pstr_primitive declaration ->
      (scope, Names.add declaration.pval_name.txt scope)
  | Pstr_module binding -> (scope, Names.add binding.pmb_name.txt scope)
  | Pstr_recmodule bindings ->
      let after =
        List.fold_left
          (fun scope binding -> Names.add binding.Parsetree.pmb_name.txt scope)
          scope bindings
      in
      (after, after)
  | Pstr_open _ | Pstr_include _ -> (scope, opaque scope)
  | _ -> (scope, scope)

let check ~(source : Source.t) tree =
  (* The compiler iterator returns unit, so diagnostics accumulate at this boundary. *)
  let diagnostics = ref [] in
  let emit rule message location =
    diagnostics :=
      Diagnostic.
        {
          filename = source.filename;
          rule;
          message;
          help = None;
          symbol = None;
          fixes = [];
          range = Source_range.of_location ~source:source.text location;
        }
      :: !diagnostics
  in
  let visitor = iterator emit Names.empty in
  (match tree with
  | Parser.Implementation structure -> visitor.structure visitor structure
  | Interface signature -> visitor.signature visitor signature);
  Source_range.sort (List.rev !diagnostics)
