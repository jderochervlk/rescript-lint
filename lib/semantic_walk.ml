open Semantic_model

type callbacks = {
  expression : scope -> Parsetree.expression -> unit;
  bound_value : value -> value;
  bindings : scope -> Asttypes.rec_flag -> Parsetree.value_binding list -> unit;
  structure_item : scope -> Parsetree.structure_item -> unit;
  module_reference : scope -> Longident.t Location.loc -> unit;
  initialization : scope -> Parsetree.structure_item -> unit;
}

let nothing =
  {
    expression = (fun _ _ -> ());
    bound_value = (fun value -> value);
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
  let names = bind_pattern empty Unknown pattern in
  let merge names values exports =
    Names.fold
      (fun name _ exports ->
        match Names.find_opt name values with
        | Some value -> Names.add name value exports
        | None -> exports)
      names exports
  in
  {
    exports with
    values = merge names.values final.values exports.values;
    modules = merge names.modules final.modules exports.modules;
  }

let type_exports scope declarations =
  let declared = List.fold_left add_declaration scope declarations in
  let names = List.fold_left add_declaration empty declarations in
  {
    empty with
    types =
      Names.filter (fun name _ -> Names.mem name names.types) declared.types;
    constructors =
      Names.filter
        (fun name _ -> Names.mem name names.constructors)
        declared.constructors;
  }

let binding_exports callbacks scope bindings =
  let exports =
    List.fold_left
      (fun exports (binding : Parsetree.value_binding) ->
        exported_pattern (bind_value scope binding) exports binding.pvb_pat)
      empty bindings
  in
  { exports with values = Names.map callbacks.bound_value exports.values }

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

let constrained_value inferred declared =
  {
    inferred with
    typ = (match declared.typ with Unknown -> inferred.typ | typ -> typ);
    attributes = declared.attributes @ inferred.attributes;
    pure = declared.pure || inferred.pure;
  }

let rec constrained inferred declared =
  let values =
    Names.mapi
      (fun name declaration ->
        Option.fold ~none:declaration
          ~some:(fun value -> constrained_value value declaration)
          (Names.find_opt name inferred.values))
      declared.values
  in
  let modules =
    Names.mapi
      (fun name declaration ->
        Option.fold ~none:declaration
          ~some:(fun scope -> constrained scope declaration)
          (Names.find_opt name inferred.modules))
      declared.modules
  in
  { declared with values; modules }

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
      expression callbacks
        (overlay inside (binding_exports callbacks inside bindings))
        body
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
  | Pmod_structure items -> snd (structure_exports callbacks scope items)
  | Pmod_constraint (inner, typ) -> (
      let inferred = module_expression callbacks scope inner in
      match typ.pmty_desc with
      | Pmty_signature items -> constrained inferred (signature scope items)
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

and structure_exports callbacks scope items =
  List.fold_left
    (fun (scope, exports) (item : Parsetree.structure_item) ->
      callbacks.structure_item scope item;
      callbacks.initialization scope item;
      let after, added = structure_item callbacks scope item in
      (after, overlay exports added))
    (scope, empty) items

and structure callbacks scope items =
  fst (structure_exports callbacks scope items)

and structure_item callbacks scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_open declaration ->
      callbacks.module_reference scope declaration.popen_lid;
      (open_path scope declaration.popen_lid.txt, empty)
  | _ ->
      let added = structure_declaration callbacks scope item in
      (overlay scope added, added)

and structure_declaration callbacks scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (flag, bindings) ->
      let inside = recursive_scope scope flag bindings in
      callbacks.bindings inside flag bindings;
      List.iter
        (fun (binding : Parsetree.value_binding) ->
          expression callbacks inside (binding_expression binding))
        bindings;
      binding_exports callbacks inside bindings
  | Pstr_eval (value, _) ->
      expression callbacks scope value;
      empty
  | Pstr_module binding ->
      add_module binding.pmb_name.txt
        (module_expression callbacks scope binding.pmb_expr)
        empty
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
        empty bindings
  | Pstr_type (_, declarations) -> type_exports scope declarations
  | Pstr_primitive value ->
      let declared = add_external scope value in
      {
        empty with
        values =
          Names.filter
            (fun name _ -> name = value.pval_name.txt)
            declared.values;
      }
  | Pstr_include declaration ->
      module_expression callbacks scope declaration.pincl_mod
  | _ -> empty

let iter callbacks scope = function
  | Parser.Implementation items -> ignore (structure callbacks scope items)
  | Interface _ -> ()
