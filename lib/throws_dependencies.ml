module Names = Map.Make (String)
module Roots = Set.Make (String)

type scope = { modules : scope Names.t; module_types : scope Names.t }
type context = { record : scope -> Longident.t -> unit }

let empty = { modules = Names.empty; module_types = Names.empty }

let bind name value scope =
  { scope with modules = Names.add name value scope.modules }

let bind_type name value scope =
  { scope with module_types = Names.add name value scope.module_types }

let overlay outer inner =
  let merge = Names.union (fun _ _ right -> Some right) in
  {
    modules = merge outer.modules inner.modules;
    module_types = merge outer.module_types inner.module_types;
  }

let rec lookup select scope = function
  | Longident.Lident name -> Names.find_opt name (select scope)
  | Ldot (parent, name) ->
      Option.bind
        (lookup (fun scope -> scope.modules) scope parent)
        (fun nested -> Names.find_opt name (select nested))
  | Lapply _ -> None

let contents scope name =
  Option.value ~default:empty (lookup (fun scope -> scope.modules) scope name)

let rec pattern_scope scope pattern =
  match pattern.Parsetree.ppat_desc with
  | Ppat_unpack name -> bind name.txt empty scope
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) | Ppat_exception inner ->
      pattern_scope scope inner
  | Ppat_tuple patterns | Ppat_array patterns ->
      List.fold_left pattern_scope scope patterns
  | _ -> nested_pattern_scope scope pattern

and nested_pattern_scope scope pattern =
  match pattern.Parsetree.ppat_desc with
  | Ppat_construct (_, Some inner) | Ppat_variant (_, Some inner) ->
      pattern_scope scope inner
  | Ppat_record (fields, _) ->
      List.fold_left
        (fun scope field -> pattern_scope scope field.Parsetree.x)
        scope fields
  | Ppat_or (left, right) -> pattern_scope (pattern_scope scope left) right
  | _ -> scope

let rec roots scope = function
  | Longident.Lident name ->
      if Names.mem name scope.modules then Roots.empty else Roots.singleton name
  | Ldot (parent, _) -> roots scope parent
  | Lapply (left, right) -> Roots.union (roots scope left) (roots scope right)

let qualified context scope = function
  | Longident.Lident _ -> ()
  | name -> context.record scope name

let attribute self ((_, payload) as attribute) =
  if Throws_annotation.is_throws attribute then
    self.Ast_iterator.payload self payload

let pattern context scope self node =
  (match node.Parsetree.ppat_desc with
  | Ppat_construct (name, _) | Ppat_type name ->
      qualified context scope name.txt
  | Ppat_record (fields, _) ->
      List.iter
        (fun field -> qualified context scope field.Parsetree.lid.txt)
        fields
  | _ -> ());
  Ast_iterator.default_iterator.pat self node

let typ context scope self node =
  (match node.Parsetree.ptyp_desc with
  | Ptyp_constr (name, _) | Ptyp_package (name, _) ->
      qualified context scope name.txt
  | _ -> ());
  Ast_iterator.default_iterator.typ self node

let extension_constructor context scope self node =
  (match node.Parsetree.pext_kind with
  | Pext_rebind name -> qualified context scope name.txt
  | _ -> ());
  Ast_iterator.default_iterator.extension_constructor self node

let type_extension context scope self node =
  qualified context scope node.Parsetree.ptyext_path.txt;
  Ast_iterator.default_iterator.type_extension self node

let open_description context scope self node =
  context.record scope node.Parsetree.popen_lid.txt;
  Ast_iterator.default_iterator.open_description self node

let with_constraint context scope self constraint_ =
  (match constraint_ with
  | Parsetree.Pwith_module (_, name) | Pwith_modsubst (_, name) ->
      context.record scope name.txt
  | _ -> ());
  Ast_iterator.default_iterator.with_constraint self constraint_

let expression_references context scope node =
  match node.Parsetree.pexp_desc with
  | Pexp_ident name | Pexp_construct (name, _) ->
      qualified context scope name.txt
  | Pexp_field (_, name) | Pexp_setfield (_, name, _) ->
      qualified context scope name.txt
  | Pexp_record (fields, _) ->
      List.iter
        (fun field -> qualified context scope field.Parsetree.lid.txt)
        fields
  | _ -> ()

let next_scopes (scope, exports) (added, opened) =
  (overlay (overlay scope added) opened, overlay exports added)

let rec visitor context scope =
  {
    Ast_iterator.default_iterator with
    attribute;
    expr = (fun _ -> expression context scope);
    pat = pattern context scope;
    typ = typ context scope;
    module_expr = (fun _ node -> ignore (module_expression context scope node));
    module_type = (fun _ node -> ignore (module_type context scope node));
    structure = (fun _ items -> ignore (structure context scope items));
    signature = (fun _ items -> ignore (signature context scope items));
    case = case context scope;
    extension_constructor = extension_constructor context scope;
    type_extension = type_extension context scope;
    open_description = open_description context scope;
    with_constraint = with_constraint context scope;
  }

and expression context scope node =
  let self = visitor context scope in
  self.attributes self node.Parsetree.pexp_attributes;
  match node.pexp_desc with
  | Pexp_letmodule (name, value, body) ->
      expression context
        (bind name.txt (module_expression context scope value) scope)
        body
  | Pexp_open (_, name, body) ->
      context.record scope name.txt;
      expression context (overlay scope (contents scope name.txt)) body
  | Pexp_fun { lhs; default; rhs; _ } ->
      self.pat self lhs;
      Option.iter (expression context scope) default;
      expression context (pattern_scope scope lhs) rhs
  | Pexp_let (_, bindings, body) ->
      List.iter (self.value_binding self) bindings;
      let nested =
        List.fold_left
          (fun scope binding -> pattern_scope scope binding.Parsetree.pvb_pat)
          scope bindings
      in
      expression context nested body
  | _ ->
      expression_references context scope node;
      Ast_iterator.default_iterator.expr self node

and case context scope self case =
  self.Ast_iterator.pat self case.Parsetree.pc_lhs;
  let nested = pattern_scope scope case.pc_lhs in
  Option.iter (expression context nested) case.pc_guard;
  expression context nested case.pc_rhs

and module_expression context scope node =
  let self = visitor context scope in
  self.attributes self node.Parsetree.pmod_attributes;
  match node.pmod_desc with
  | Pmod_ident name ->
      context.record scope name.txt;
      contents scope name.txt
  | Pmod_structure items -> structure context scope items
  | Pmod_functor (name, parameter, body) ->
      let parameter =
        Option.fold ~none:empty ~some:(module_type context scope) parameter
      in
      ignore (module_expression context (bind name.txt parameter scope) body);
      empty
  | Pmod_constraint (body, typ) ->
      ignore (module_expression context scope body);
      module_type context scope typ
  | _ ->
      Ast_iterator.default_iterator.module_expr self node;
      empty

and module_type context scope node =
  let self = visitor context scope in
  self.attributes self node.Parsetree.pmty_attributes;
  match node.pmty_desc with
  | Pmty_signature items -> signature context scope items
  | Pmty_alias name ->
      context.record scope name.txt;
      contents scope name.txt
  | Pmty_ident name ->
      qualified context scope name.txt;
      Option.value ~default:empty
        (lookup (fun scope -> scope.module_types) scope name.txt)
  | Pmty_typeof node -> module_expression context scope node
  | _ -> extended_module_type context scope self node

and extended_module_type context scope self node =
  match node.Parsetree.pmty_desc with
  | Pmty_functor (name, parameter, body) ->
      let parameter =
        Option.fold ~none:empty ~some:(module_type context scope) parameter
      in
      ignore (module_type context (bind name.txt parameter scope) body);
      empty
  | _ ->
      Ast_iterator.default_iterator.module_type self node;
      empty

and structure context scope items =
  List.fold_left
    (fun ((scope, _) as scopes) item ->
      next_scopes scopes (structure_item context scope item))
    (scope, empty) items
  |> snd

and structure_item context scope item =
  let self = visitor context scope in
  match item.Parsetree.pstr_desc with
  | Pstr_module binding -> (module_binding context scope binding, empty)
  | Pstr_recmodule bindings -> (recursive_bindings context scope bindings, empty)
  | Pstr_include inclusion ->
      self.attributes self inclusion.pincl_attributes;
      (module_expression context scope inclusion.pincl_mod, empty)
  | Pstr_modtype declaration ->
      (module_type_declaration context scope declaration, empty)
  | _ -> structure_other scope self item

and structure_other scope self item =
  match item.Parsetree.pstr_desc with
  | Pstr_open opening ->
      self.Ast_iterator.open_description self opening;
      (empty, contents scope opening.popen_lid.txt)
  | _ ->
      self.structure_item self item;
      (empty, empty)

and module_binding context scope binding =
  let self = visitor context scope in
  self.attributes self binding.Parsetree.pmb_attributes;
  bind binding.pmb_name.txt
    (module_expression context scope binding.pmb_expr)
    empty

and recursive_bindings context scope bindings =
  let nested =
    List.fold_left
      (fun scope binding -> bind binding.Parsetree.pmb_name.txt empty scope)
      scope bindings
  in
  List.fold_left
    (fun exports binding ->
      overlay exports (module_binding context nested binding))
    empty bindings

and signature context scope items =
  List.fold_left
    (fun ((scope, _) as scopes) item ->
      next_scopes scopes (signature_item context scope item))
    (scope, empty) items
  |> snd

and signature_item context scope item =
  let self = visitor context scope in
  match item.Parsetree.psig_desc with
  | Psig_module declaration ->
      (module_declaration context scope declaration, empty)
  | Psig_recmodule declarations ->
      (recursive_declarations context scope declarations, empty)
  | Psig_include inclusion ->
      self.attributes self inclusion.pincl_attributes;
      (module_type context scope inclusion.pincl_mod, empty)
  | Psig_modtype declaration ->
      (module_type_declaration context scope declaration, empty)
  | _ -> signature_other scope self item

and signature_other scope self item =
  match item.Parsetree.psig_desc with
  | Psig_open opening ->
      self.Ast_iterator.open_description self opening;
      (empty, contents scope opening.popen_lid.txt)
  | _ ->
      self.signature_item self item;
      (empty, empty)

and module_declaration context scope declaration =
  let self = visitor context scope in
  self.attributes self declaration.Parsetree.pmd_attributes;
  bind declaration.pmd_name.txt
    (module_type context scope declaration.pmd_type)
    empty

and recursive_declarations context scope declarations =
  let nested =
    List.fold_left
      (fun scope declaration ->
        bind declaration.Parsetree.pmd_name.txt empty scope)
      scope declarations
  in
  List.fold_left
    (fun exports declaration ->
      overlay exports (module_declaration context nested declaration))
    empty declarations

and module_type_declaration context scope declaration =
  let self = visitor context scope in
  self.attributes self declaration.Parsetree.pmtd_attributes;
  let contents =
    Option.fold ~none:empty
      ~some:(module_type context scope)
      declaration.pmtd_type
  in
  bind_type declaration.pmtd_name.txt contents empty

let modules ~project_modules tree =
  let project = Roots.of_list project_modules and found = ref Roots.empty in
  let record scope path =
    found := Roots.union !found (Roots.inter project (roots scope path))
  in
  let self = visitor { record } empty in
  (match tree with
  | Parser.Implementation items -> self.structure self items
  | Interface items -> self.signature self items);
  Roots.elements !found
