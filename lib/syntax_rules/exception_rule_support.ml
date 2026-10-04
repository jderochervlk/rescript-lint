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

let opaque scope = Names.union scope builtins
