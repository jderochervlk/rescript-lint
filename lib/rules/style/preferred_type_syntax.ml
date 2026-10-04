let metadata =
  Rule_metadata.
    {
      id = "preferred-type-syntax";
      category = Style;
      enabled_by_default = false;
    }

let dictionary emit scope (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr (identifier, [ _ ])
    when Semantic_model.standard_type scope identifier.txt
         = Some [ "Dict"; "t" ] ->
      emit "preferred-type-syntax"
        "Prefer the builtin dict type to the standard Dict.t alias."
        identifier.loc
  | _ -> ()
