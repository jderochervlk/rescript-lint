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
  let metadata =
    Semantic_model.Names.find_opt name scope.Semantic_model.values
  in
  let typ =
    match metadata with
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
  let origin =
    match metadata with
    | Some value -> value.declaration_origin
    | None -> Semantic_model.Unavailable
  in
  ( Ast_helper.Sig.value ~loc:binding.pvb_loc
      (Ast_helper.Val.mk ~loc:binding.pvb_loc ~attrs:binding.pvb_attributes
         (Location.mknoloc name) typ),
    ([ name ], origin) )

type origins = {
  values : (string list * Semantic_model.provenance) list;
  types : (string list * Semantic_model.type_origin) list;
}

let no_origins = { values = []; types = [] }

let combine exports =
  ( List.concat_map fst exports,
    {
      values = List.concat_map (fun (_, origins) -> origins.values) exports;
      types = List.concat_map (fun (_, origins) -> origins.types) exports;
    } )

let rec scope_origins scope =
  let nested =
    Semantic_model.Names.bindings scope.Semantic_model.modules
    |> List.map (fun (name, scope) -> prefix_origins name (scope_origins scope))
  in
  {
    values =
      List.map
        (fun (name, value) ->
          ([ name ], value.Semantic_model.declaration_origin))
        (Semantic_model.Names.bindings scope.values)
      @ List.concat_map (fun origins -> origins.values) nested;
    types =
      List.map
        (fun (name, origin) -> ([ name ], origin))
        (Semantic_model.Names.bindings scope.type_identities)
      @ List.concat_map (fun origins -> origins.types) nested;
  }

and prefix_origins name origins =
  let prefix entries =
    List.map (fun (path, origin) -> (name :: path, origin)) entries
  in
  { values = prefix origins.values; types = prefix origins.types }

let resolved_module_name scope identifier (name : Longident.t Location.loc) =
  match
    Option.bind
      (Semantic_model.module_identity scope identifier)
      Longident.unflatten
  with
  | Some path -> { name with txt = path }
  | None -> name

let resolved_module_expression scope (expression : Parsetree.module_expr) =
  match expression.pmod_desc with
  | Pmod_ident name ->
      {
        expression with
        pmod_desc = Pmod_ident (resolved_module_name scope name.txt name);
      }
  | _ -> expression

let rec items scope structure = List.map (item scope) structure |> combine

and item scope (node : Parsetree.structure_item) =
  match node.pstr_desc with
  | Pstr_value (_, bindings) ->
      let values =
        List.concat_map
          (fun binding ->
            List.map (value scope binding)
              (Project_exports.pattern_names binding.Parsetree.pvb_pat))
          bindings
      in
      (List.map fst values, { no_origins with values = List.map snd values })
  | Pstr_type (recursive, declarations) ->
      ([ Ast_helper.Sig.type_ recursive declarations ], no_origins)
  | Pstr_primitive value -> ([ Ast_helper.Sig.value value ], no_origins)
  | Pstr_module binding -> module_item scope binding
  | Pstr_recmodule bindings -> List.map (module_item scope) bindings |> combine
  | Pstr_include inclusion ->
      let typ, origins =
        match inclusion.pincl_mod.pmod_desc with
        | Pmod_structure structure ->
            let signature, origins = items scope structure in
            (Ast_helper.Mty.signature signature, origins)
        | Pmod_constraint (_, typ) ->
            ( typ,
              scope_origins
                (Semantic_walk.module_expression Semantic_walk.nothing scope
                   inclusion.pincl_mod) )
        | _ ->
            ( Ast_helper.Mty.typeof_
                (resolved_module_expression scope inclusion.pincl_mod),
              no_origins )
      in
      ([ Ast_helper.Sig.include_ (Ast_helper.Incl.mk typ) ], origins)
  | _ -> ([], no_origins)

and module_item scope (binding : Parsetree.module_binding) =
  let signature, origins =
    match binding.pmb_expr.pmod_desc with
    | Pmod_constraint (_, typ) ->
        let nested =
          Option.value ~default:Semantic_model.unknown
            (Semantic_model.module_path scope [ binding.pmb_name.txt ])
        in
        (typ, scope_origins nested)
    | Pmod_structure structure ->
        let nested =
          Option.value ~default:Semantic_model.empty
            (Semantic_model.module_path scope [ binding.pmb_name.txt ])
        in
        let signature, origins = items nested structure in
        (Ast_helper.Mty.signature signature, origins)
    | Pmod_ident name ->
        let exported = Longident.Lident binding.pmb_name.txt in
        ( Ast_helper.Mty.alias (resolved_module_name scope exported name),
          no_origins )
    | _ -> (Ast_helper.Mty.typeof_ binding.pmb_expr, no_origins)
  in
  ( [ Ast_helper.Sig.module_ (Ast_helper.Md.mk binding.pmb_name signature) ],
    prefix_origins binding.pmb_name.txt origins )

let of_structure_with_declaration_origins ~context structure =
  let scope =
    Semantic_walk.structure Semantic_walk.nothing
      (Semantic_runtime.initial_scope context)
      structure
  in
  items scope structure

let of_structure_with_origins ~context structure =
  let signature, origins =
    of_structure_with_declaration_origins ~context structure
  in
  (signature, origins.values)

let of_structure ~context structure =
  fst (of_structure_with_origins ~context structure)
