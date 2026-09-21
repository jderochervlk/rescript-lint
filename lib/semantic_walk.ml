open Semantic_model

type callbacks = {
  expression : scope -> Parsetree.expression -> unit;
  bindings : scope -> Asttypes.rec_flag -> Parsetree.value_binding list -> unit;
  structure_item : scope -> Parsetree.structure_item -> unit;
  module_reference : scope -> Longident.t Location.loc -> unit;
  initialization : scope -> Parsetree.structure_item -> unit;
}

let nothing =
  {
    expression = (fun _ _ -> ());
    bindings = (fun _ _ _ -> ());
    structure_item = (fun _ _ -> ());
    module_reference = (fun _ _ -> ());
    initialization = (fun _ _ -> ());
  }

let recursive_scope scope flag bindings =
  match flag with
  | Asttypes.Nonrecursive -> scope
  | Recursive ->
      List.fold_left
        (fun scope (binding : Parsetree.value_binding) ->
          bind_pattern scope (infer scope binding.pvb_expr) binding.pvb_pat)
        scope bindings

let exported_pattern final exports pattern =
  let names = (bind_pattern empty Unknown pattern).values in
  Names.fold
    (fun name _ exports ->
      match Names.find_opt name final.values with
      | Some value -> add_value name value exports
      | None -> exports)
    names exports

let binding_scope scope bindings =
  let exports =
    List.fold_left
      (fun exports (binding : Parsetree.value_binding) ->
        exported_pattern (bind_value scope binding) exports binding.pvb_pat)
      empty bindings
  in
  overlay scope exports

let binding_expression (binding : Parsetree.value_binding) =
  let attributes =
    List.filter
      (fun ((name : string Location.loc), _) ->
        String.starts_with ~prefix:"lint." name.txt)
      binding.pvb_attributes
  in
  match attributes with
  | [] -> binding.pvb_expr
  | _ ->
      {
        binding.pvb_expr with
        pexp_attributes = attributes @ binding.pvb_expr.pexp_attributes;
      }

let rec exports final items =
  List.fold_left
    (fun exports (item : Parsetree.structure_item) ->
      match item.pstr_desc with
      | Pstr_value (_, bindings) ->
          List.fold_left
            (fun exports (binding : Parsetree.value_binding) ->
              exported_pattern final exports binding.pvb_pat)
            exports bindings
      | Pstr_module binding -> (
          match Names.find_opt binding.pmb_name.txt final.modules with
          | Some nested -> add_module binding.pmb_name.txt nested exports
          | None -> exports)
      | Pstr_primitive value -> (
          match Names.find_opt value.pval_name.txt final.values with
          | Some value_ -> add_value value.pval_name.txt value_ exports
          | None -> exports)
      | Pstr_include inclusion ->
          overlay exports (included_exports final inclusion.pincl_mod)
      | Pstr_recmodule bindings ->
          List.fold_left
            (fun exports (binding : Parsetree.module_binding) ->
              match Names.find_opt binding.pmb_name.txt final.modules with
              | Some nested -> add_module binding.pmb_name.txt nested exports
              | None -> exports)
            exports bindings
      | Pstr_type (_, declarations) ->
          List.fold_left add_declaration exports declarations
      | _ -> exports)
    empty items

and included_exports final (node : Parsetree.module_expr) =
  match node.pmod_desc with
  | Pmod_ident name ->
      Option.value ~default:unknown
        (Option.bind (path name.txt) (module_path final))
  | Pmod_structure items -> exports final items
  | Pmod_constraint (_, { pmty_desc = Pmty_signature items; _ }) ->
      signature final items
  | _ -> unknown

let rec expression callbacks scope (node : Parsetree.expression) =
  callbacks.expression scope node;
  match node.pexp_desc with
  | Pexp_let (flag, bindings, body) ->
      let inside = recursive_scope scope flag bindings in
      callbacks.bindings inside flag bindings;
      List.iter
        (fun (binding : Parsetree.value_binding) ->
          expression callbacks inside (binding_expression binding))
        bindings;
      expression callbacks (binding_scope inside bindings) body
  | Pexp_fun { lhs; default; rhs; _ } ->
      let deferred = { callbacks with initialization = (fun _ _ -> ()) } in
      Option.iter (expression deferred scope) default;
      expression deferred (bind_pattern scope (pattern_type scope lhs) lhs) rhs
  | Pexp_match (value, cases) | Pexp_try (value, cases) ->
      expression callbacks scope value;
      List.iter (case callbacks scope (infer scope value)) cases
  | Pexp_for (pattern, start, finish, _, body) ->
      expression callbacks scope start;
      expression callbacks scope finish;
      expression callbacks (bind_pattern scope Int pattern) body
  | Pexp_letmodule (name, value, body) ->
      let nested = module_expression callbacks scope value in
      expression callbacks (add_module name.txt nested scope) body
  | Pexp_open (_, name, body) ->
      callbacks.module_reference scope name;
      expression callbacks (open_path scope name.txt) body
  | _ -> children callbacks scope node

and children callbacks scope node =
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      expr = (fun _ child -> expression callbacks scope child);
      module_expr =
        (fun _ child -> ignore (module_expression callbacks scope child));
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  default.expr visitor node

and case callbacks scope typ (case : Parsetree.case) =
  let nested = bind_pattern scope typ case.pc_lhs in
  Option.iter (expression callbacks nested) case.pc_guard;
  expression callbacks nested case.pc_rhs

and module_expression callbacks scope (node : Parsetree.module_expr) =
  match node.pmod_desc with
  | Pmod_ident name ->
      callbacks.module_reference scope name;
      Option.value ~default:unknown
        (Option.bind (path name.txt) (module_path scope))
  | Pmod_structure items -> exports (structure callbacks scope items) items
  | Pmod_constraint (inner, typ) -> (
      let inferred = module_expression callbacks scope inner in
      match typ.pmty_desc with
      | Pmty_signature items ->
          let declared = signature scope items in
          let values =
            Names.mapi
              (fun name declaration ->
                Option.value ~default:declaration
                  (Names.find_opt name inferred.values))
              declared.values
          in
          { declared with values }
      | _ -> unknown)
  | Pmod_functor (name, _, body) ->
      let deferred = { callbacks with initialization = (fun _ _ -> ()) } in
      ignore
        (module_expression deferred (add_module name.txt unknown scope) body);
      unknown
  | Pmod_apply (functor_, argument) ->
      ignore (module_expression callbacks scope functor_);
      ignore (module_expression callbacks scope argument);
      unknown
  | Pmod_unpack value ->
      expression callbacks scope value;
      unknown
  | _ -> unknown

and structure callbacks scope = function
  | [] -> scope
  | (item : Parsetree.structure_item) :: rest ->
      callbacks.structure_item scope item;
      callbacks.initialization scope item;
      let after = structure_item callbacks scope item in
      structure callbacks after rest

and structure_item callbacks scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (flag, bindings) ->
      let inside = recursive_scope scope flag bindings in
      callbacks.bindings inside flag bindings;
      List.iter
        (fun (binding : Parsetree.value_binding) ->
          expression callbacks inside (binding_expression binding))
        bindings;
      binding_scope inside bindings
  | Pstr_eval (value, _) ->
      expression callbacks scope value;
      scope
  | Pstr_module binding ->
      add_module binding.pmb_name.txt
        (module_expression callbacks scope binding.pmb_expr)
        scope
  | Pstr_recmodule bindings ->
      let inside =
        List.fold_left
          (fun scope (binding : Parsetree.module_binding) ->
            add_module binding.pmb_name.txt unknown scope)
          scope bindings
      in
      List.fold_left
        (fun scope (binding : Parsetree.module_binding) ->
          add_module binding.pmb_name.txt
            (module_expression callbacks inside binding.pmb_expr)
            scope)
        inside bindings
  | Pstr_type (_, declarations) ->
      List.fold_left add_declaration scope declarations
  | Pstr_primitive value -> add_external scope value
  | Pstr_open declaration ->
      callbacks.module_reference scope declaration.popen_lid;
      open_path scope declaration.popen_lid.txt
  | Pstr_include declaration ->
      overlay scope (module_expression callbacks scope declaration.pincl_mod)
  | _ -> scope

let iter callbacks scope = function
  | Parser.Implementation items -> ignore (structure callbacks scope items)
  | Interface _ -> ()
