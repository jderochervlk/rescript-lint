let metadata =
  Rule_metadata.
    {
      id = "react/no-array-index-key";
      category = Perf;
      enabled_by_default = false;
    }

open React_dom_support

let rec index_expression index (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ident { txt = Lident name; _ } -> name = index
  | Pexp_constraint (inner, _) -> index_expression index inner
  | Pexp_apply { funct; args; partial = false; _ } ->
      index_application index funct args
  | _ -> false

and index_application index funct args =
  match (expression_path funct, args) with
  | Some [ "Int"; "toString" ], [ (_, value) ] -> index_expression index value
  | Some [ "->" ], [ (_, value); (_, target) ] ->
      expression_path target = Some [ "Int"; "toString" ]
      && index_expression index value
  | _ -> false

let inspect ~emit index element =
  match (index, M.prop "key" element) with
  | Some index, Value value when index_expression index value ->
      emit "no-array-index-key"
        "Use a stable item identifier instead of the collection index as the \
         key."
        element.M.location
  | _ -> ()
