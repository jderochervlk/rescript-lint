type declaration = { path : string list; location : Location.t }

let rec pattern_names (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name -> [ name.txt ]
  | Ppat_alias (inner, name) -> name.txt :: pattern_names inner
  | Ppat_constraint (inner, _) -> pattern_names inner
  | Ppat_tuple patterns | Ppat_array patterns ->
      List.concat_map pattern_names patterns
  | Ppat_record (fields, _) ->
      List.concat_map (fun field -> pattern_names field.Parsetree.x) fields
  | Ppat_construct (_, Some inner)
  | Ppat_variant (_, Some inner)
  | Ppat_exception inner
  | Ppat_open (_, inner) ->
      pattern_names inner
  | Ppat_or (left, right) ->
      List.sort_uniq String.compare (pattern_names left @ pattern_names right)
  | _ -> []

let rec structure prefix items = List.concat_map (structure_item prefix) items

and structure_item prefix (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (_, bindings) ->
      List.concat_map
        (fun (binding : Parsetree.value_binding) ->
          List.map
            (fun name ->
              { path = prefix @ [ name ]; location = binding.pvb_loc })
            (pattern_names binding.pvb_pat))
        bindings
  | Pstr_primitive value ->
      [ { path = prefix @ [ value.pval_name.txt ]; location = value.pval_loc } ]
  | Pstr_module binding ->
      module_expression (prefix @ [ binding.pmb_name.txt ]) binding.pmb_expr
  | Pstr_recmodule bindings ->
      List.concat_map
        (fun (binding : Parsetree.module_binding) ->
          module_expression (prefix @ [ binding.pmb_name.txt ]) binding.pmb_expr)
        bindings
  | Pstr_include inclusion -> module_expression prefix inclusion.pincl_mod
  | _ -> []

and module_expression prefix (expression : Parsetree.module_expr) =
  match expression.pmod_desc with
  | Pmod_structure items -> structure prefix items
  | Pmod_constraint (body, { pmty_desc = Pmty_signature signature; _ }) ->
      let exposed = signatures prefix signature in
      List.filter
        (fun declaration ->
          List.exists (fun public -> declaration.path = public.path) exposed)
        (module_expression prefix body)
  | _ -> []

and signatures prefix items = List.concat_map (signature_item prefix) items

and signature_item prefix (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value value ->
      [ { path = prefix @ [ value.pval_name.txt ]; location = value.pval_loc } ]
  | Psig_module declaration ->
      module_type (prefix @ [ declaration.pmd_name.txt ]) declaration.pmd_type
  | Psig_recmodule declarations ->
      List.concat_map
        (fun (declaration : Parsetree.module_declaration) ->
          module_type
            (prefix @ [ declaration.pmd_name.txt ])
            declaration.pmd_type)
        declarations
  | Psig_include inclusion -> module_type prefix inclusion.pincl_mod
  | _ -> []

and module_type prefix (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> signatures prefix items
  | _ -> []

let declarations = function
  | Parser.Implementation items -> structure [] items
  | Interface items -> signatures [] items

let public project unit =
  let values = declarations unit.Project_files.tree in
  match Project_files.signature project unit.name with
  | None -> values
  | Some interface ->
      let exports = signatures [] interface in
      List.filter
        (fun value ->
          List.exists (fun export -> export.path = value.path) exports)
        values
