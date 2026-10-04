let integer (expression : Parsetree.expression) =
  match (Semantic_model.unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_integer (value, None)) -> int_of_string_opt value
  | _ -> None

let operator ~source scope (funct : Parsetree.expression) =
  match funct.pexp_desc with
  | Pexp_ident ({ txt = Lident "mod"; _ } as identifier) ->
      Option.bind (Semantic_model.resolve scope identifier.txt) (fun value ->
          if value.api = Some [ "Stdlib"; "mod" ] then Some "mod" else None)
  | _ -> (
      match Expression_rules.operator ~source funct with
      | Some "%" -> Some "mod"
      | name -> name)
