module M = Jsx_model
module Names = Set.Make (String)

let issue name condition message = if condition then [ (name, message) ] else []

let has_children element =
  element.M.children <> [] || M.present "children" element

let rec expression_path (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ident name -> Some (path name.txt)
  | Pexp_constraint (inner, _) -> expression_path inner
  | _ -> None

and path = function
  | Longident.Lident name -> [ name ]
  | Ldot (parent, name) -> path parent @ [ name ]
  | Lapply _ -> []

let rec parameters remaining collected (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_fun { lhs; rhs; _ } when remaining > 0 ->
      parameters (remaining - 1) (lhs :: collected) rhs
  | _ -> (List.rev collected, expression)

let rec function_parts (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_fun { arity; _ } ->
      Some (parameters (Option.value ~default:1 arity) [] expression)
  | Pexp_constraint (inner, _) -> function_parts inner
  | _ -> None

let rec pattern_name (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name -> Some name.txt
  | Ppat_constraint (inner, _) -> pattern_name inner
  | _ -> None

let pattern_names pattern =
  let names = ref Names.empty in
  let visitor =
    {
      Ast_iterator.default_iterator with
      pat =
        (fun iterator pattern ->
          (match pattern.Parsetree.ppat_desc with
          | Ppat_var name | Ppat_alias (_, name) ->
              names := Names.add name.txt !names
          | _ -> ());
          Ast_iterator.default_iterator.pat iterator pattern);
    }
  in
  visitor.pat visitor pattern;
  !names

let without_pattern index pattern =
  Option.bind index (fun name ->
      if Names.mem name (pattern_names pattern) then None else Some name)

let static_collection (expression : Parsetree.expression) =
  let literal (expression : Parsetree.expression) =
    match expression.pexp_desc with
    | Pexp_constant _ | Pexp_construct (_, None) | Pexp_variant (_, None) ->
        true
    | _ -> false
  in
  match expression.pexp_desc with
  | Pexp_array values -> List.for_all literal values
  | _ -> false

type index_position = No_index | First | Second

let collection_call ~array_unshadowed ~list_unshadowed ~belt_unshadowed funct
    arguments =
  match (expression_path funct, arguments) with
  | ( Some [ "Array"; (("map" | "mapWithIndex") as name) ],
      [ (_, collection); (_, callback) ] )
    when array_unshadowed ->
      Some
        ( (if name = "mapWithIndex" then Second else No_index),
          collection,
          callback )
  | ( Some [ "List"; (("map" | "mapWithIndex") as name) ],
      [ (_, collection); (_, callback) ] )
    when list_unshadowed ->
      Some
        ( (if name = "mapWithIndex" then Second else No_index),
          collection,
          callback )
  | ( Some [ "Belt"; ("Array" | "List"); (("map" | "mapWithIndex") as name) ],
      [ (_, collection); (_, callback) ] )
    when belt_unshadowed ->
      Some
        ( (if name = "mapWithIndex" then First else No_index),
          collection,
          callback )
  | _ -> None

let call_parts (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_apply
      { funct; args = [ (_, collection); (_, target) ]; partial = false; _ }
    when expression_path funct = Some [ "->" ] -> (
      match target.pexp_desc with
      | Pexp_apply { funct; args; partial = false; _ } ->
          Some (funct, (Asttypes.Nolabel, collection) :: args)
      | _ -> None)
  | Pexp_apply { funct; args; partial = false; _ } -> Some (funct, args)
  | _ -> None
