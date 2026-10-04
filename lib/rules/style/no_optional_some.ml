let metadata =
  Rule_metadata.
    { id = "no-optional-some"; category = Style; enabled_by_default = false }

let optional_some emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_apply { args; _ } ->
      List.iter
        (function
          | ( Asttypes.Optional label,
              ({
                 Parsetree.pexp_desc =
                   Pexp_construct ({ txt = Lident "Some"; _ }, Some _);
                 _;
               } as argument) )
            when Semantic_model.Names.find_opt "Some"
                   scope.Semantic_model.constructors
                 = Some (Semantic_model.Option Unknown) ->
              emit "no-optional-some"
                ("Pass ~" ^ label.txt
               ^ " directly instead of wrapping it in Some for an optional \
                  argument.")
                argument.pexp_loc
          | _ -> ())
        args
  | _ -> ()
