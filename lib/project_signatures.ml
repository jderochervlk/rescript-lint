let named name arguments =
  Ast_helper.Typ.constr (Location.mknoloc (Longident.Lident name)) arguments

let rec type_ast = function
  | Semantic_model.Unit -> named "unit" []
  | Bool -> named "bool" []
  | Int -> named "int" []
  | Float -> named "float" []
  | String -> named "string" []
  | Array typ -> named "array" [ type_ast typ ]
  | List typ -> named "list" [ type_ast typ ]
  | Option typ -> named "option" [ type_ast typ ]
  | Promise typ -> named "promise" [ type_ast typ ]
  | Result typ -> named "result" [ type_ast typ; Ast_helper.Typ.any () ]
  | Tuple types -> Ast_helper.Typ.tuple (List.map type_ast types)
  | Function (parameters, result) ->
      let args =
        List.map
          (fun (lbl, typ) -> Parsetree.{ attrs = []; lbl; typ = type_ast typ })
          parameters
      in
      Ast_helper.Typ.arrows args (type_ast result)
  | Unknown | Record _ | Variant _ | Regexp -> Ast_helper.Typ.any ()

let value scope binding name =
  let typ =
    match Semantic_model.Names.find_opt name scope.Semantic_model.values with
    | Some value -> type_ast value.typ
    | None -> Ast_helper.Typ.any ()
  in
  let typ =
    match binding.Parsetree.pvb_pat.ppat_desc with
    | Ppat_constraint (_, annotation)
      when Semantic_model.pattern_name binding.pvb_pat = Some name ->
        annotation
    | _ -> typ
  in
  Ast_helper.Sig.value ~loc:binding.pvb_loc
    (Ast_helper.Val.mk ~loc:binding.pvb_loc ~attrs:binding.pvb_attributes
       (Location.mknoloc name) typ)

let rec items scope structure = List.concat_map (item scope) structure

and item scope (node : Parsetree.structure_item) =
  match node.pstr_desc with
  | Pstr_value (_, bindings) ->
      List.concat_map
        (fun binding ->
          List.map (value scope binding)
            (Project_exports.pattern_names binding.Parsetree.pvb_pat))
        bindings
  | Pstr_type (recursive, declarations) ->
      [ Ast_helper.Sig.type_ recursive declarations ]
  | Pstr_primitive value -> [ Ast_helper.Sig.value value ]
  | Pstr_module binding -> module_item scope binding
  | Pstr_recmodule bindings -> List.concat_map (module_item scope) bindings
  | Pstr_include inclusion ->
      let typ =
        match inclusion.pincl_mod.pmod_desc with
        | Pmod_structure structure ->
            Ast_helper.Mty.signature (items scope structure)
        | _ -> Ast_helper.Mty.typeof_ inclusion.pincl_mod
      in
      [ Ast_helper.Sig.include_ (Ast_helper.Incl.mk typ) ]
  | _ -> []

and module_item scope (binding : Parsetree.module_binding) =
  let signature =
    match binding.pmb_expr.pmod_desc with
    | Pmod_constraint (_, typ) -> typ
    | Pmod_structure structure ->
        let nested =
          Option.value ~default:Semantic_model.empty
            (Semantic_model.module_path scope [ binding.pmb_name.txt ])
        in
        Ast_helper.Mty.signature (items nested structure)
    | Pmod_ident name -> Ast_helper.Mty.alias name
    | _ -> Ast_helper.Mty.typeof_ binding.pmb_expr
  in
  [ Ast_helper.Sig.module_ (Ast_helper.Md.mk binding.pmb_name signature) ]

let of_structure ~context structure =
  let scope =
    Semantic_walk.structure Semantic_walk.nothing
      (Semantic_model.initial context)
      structure
  in
  items scope structure
