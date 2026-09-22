module Names = Set.Make (String)

let builtins = Names.of_list [ "throw"; "raise"; "Pervasives" ]

let bind_pattern scope pattern =
  let names = ref scope in
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      pat =
        (fun self pattern ->
          (match pattern.Parsetree.ppat_desc with
          | Ppat_var name | Ppat_alias (_, name) | Ppat_unpack name ->
              names := Names.add name.txt !names
          | _ -> ());
          default.pat self pattern);
      attributes = (fun _ _ -> ());
    }
  in
  visitor.pat visitor pattern;
  !names

let bind_bindings =
  List.fold_left (fun scope binding ->
      bind_pattern scope binding.Parsetree.pvb_pat)

let rec caught_names (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name -> Names.singleton name.txt
  | Ppat_alias (inner, name) -> Names.add name.txt (caught_names inner)
  | Ppat_constraint (inner, _) | Ppat_exception inner -> caught_names inner
  | Ppat_or (left, right) ->
      Names.inter (caught_names left) (caught_names right)
  | _ -> Names.empty

let rec catch_all (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_any | Ppat_var _ -> true
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) -> catch_all inner
  | Ppat_or (left, right) -> catch_all left || catch_all right
  | _ -> false

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) -> unwrap inner
  | _ -> expression

let raise_function scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident { txt = Lident (("throw" | "raise") as name); _ } ->
      not (Names.mem name scope)
  | Pexp_ident { txt = Ldot (Lident "Pervasives", ("throw" | "raise")); _ } ->
      not (Names.mem "Pervasives" scope)
  | _ -> false

let rethrows scope pattern expression =
  match (unwrap expression).pexp_desc with
  | Pexp_apply { funct; args = [ (Nolabel, argument) ]; partial = false; _ }
    when raise_function (bind_pattern scope pattern) funct -> (
      match (unwrap argument).pexp_desc with
      | Pexp_ident { txt = Lident name; _ } ->
          Names.mem name (caught_names pattern)
      | _ -> false)
  | _ -> false

let useless_case scope (case : Parsetree.case) =
  Option.is_none case.pc_guard && rethrows scope case.pc_lhs case.pc_rhs

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
  | Pexp_extension ({ txt = "debugger"; _ }, _) ->
      emit "no-debugger" "Remove this debugger expression." expression.pexp_loc
  | Pexp_try (_, cases) ->
      if cases <> [] && List.for_all (useless_case scope) cases then
        emit "no-useless-catch"
          "This catch only rethrows the original exception." expression.pexp_loc;
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

let opaque scope = Names.union scope builtins

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
