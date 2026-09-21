module M = Jsx_model
module Names = Set.Make (String)

let rule_ids =
  List.map
    (fun name -> "react/" ^ name)
    [
      "jsx-key";
      "no-array-index-key";
      "no-children-prop";
      "no-danger-with-children";
      "void-dom-elements-no-children";
      "button-has-type";
      "jsx-no-target-blank";
      "iframe-missing-sandbox";
    ]

let issue name condition message = if condition then [ (name, message) ] else []

let void_tags =
  M.words
    "area base br col embed hr img input keygen link meta param source track \
     wbr"

let has_children element =
  element.M.children <> [] || M.present "children" element

let external_target element =
  match M.prop "href" element with
  | M.Missing -> false
  | Unknown -> false
  | Value expression -> (
      match M.string expression with
      | None -> true
      | Some text ->
          String.starts_with ~prefix:"https://" text
          || String.starts_with ~prefix:"http://" text
          || String.starts_with ~prefix:"//" text)

let unsafe_relation element =
  match M.prop "rel" element with
  | M.Missing -> true
  | Unknown -> false
  | Value expression ->
      Option.exists
        (fun text ->
          let words = M.words (String.lowercase_ascii text) in
          not (List.mem "noopener" words || List.mem "noreferrer" words))
        (M.string expression)

let dom_issues tag element =
  issue "no-danger-with-children"
    (M.present "dangerouslySetInnerHTML" element && has_children element)
    "Choose children or dangerouslySetInnerHTML, not both."
  @ issue "void-dom-elements-no-children"
      (List.mem tag void_tags
      && (has_children element || M.present "dangerouslySetInnerHTML" element))
      "Void DOM elements cannot have children or inner HTML."
  @ issue "button-has-type"
      (tag = "button" && M.absent "type_" element)
      "Declare this button's type_ to make form submission intentional."
  @ issue "jsx-no-target-blank"
      (List.mem tag [ "a"; "area" ]
      && M.string_prop "target" element = Some "_blank"
      && external_target element && unsafe_relation element)
      "Protect this new browsing context with rel=\"noopener noreferrer\"."
  @ issue "iframe-missing-sandbox"
      (tag = "iframe" && M.absent "sandbox" element)
      "Declare an iframe sandbox and grant only the capabilities it needs."

let element_issues element =
  issue "no-children-prop"
    (M.present "children" element)
    "Pass children between the JSX opening and closing tags."
  @ Option.fold ~none:[]
      ~some:(fun tag -> dom_issues tag element)
      (M.intrinsic_tag element)

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

let inspect_key ~emit index element =
  if M.absent "key" element then
    emit "jsx-key" "Give each element in a rendered collection a stable key."
      element.M.location;
  match (index, M.prop "key" element) with
  | Some index, Value value when index_expression index value ->
      emit "no-array-index-key"
        "Use a stable item identifier instead of the collection index as the \
         key."
        element.location
  | _ -> ()

let without_pattern index pattern =
  Option.bind index (fun name ->
      if Names.mem name (pattern_names pattern) then None else Some name)

let rec rendered ~emit index (expression : Parsetree.expression) =
  match M.of_expression expression with
  | Some element -> inspect_key ~emit index element
  | None -> rendered_expression ~emit index expression

and rendered_expression ~emit index (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_let (_, bindings, body) ->
      let index =
        List.fold_left
          (fun index binding -> without_pattern index binding.Parsetree.pvb_pat)
          index bindings
      in
      rendered ~emit index body
  | Pexp_sequence (_, body) | Pexp_constraint (body, _) ->
      rendered ~emit index body
  | Pexp_ifthenelse (_, yes, no) ->
      rendered ~emit index yes;
      Option.iter (rendered ~emit index) no
  | Pexp_match (_, cases) | Pexp_try (_, cases) ->
      List.iter
        (fun case ->
          rendered ~emit
            (without_pattern index case.Parsetree.pc_lhs)
            case.pc_rhs)
        cases
  | Pexp_array values -> List.iter (rendered ~emit index) values
  | _ -> ()

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

let inspect_collection ~emit ~int_unshadowed = function
  | None -> ()
  | Some (indexed, collection, callback) ->
      Option.iter
        (fun (patterns, body) ->
          let index =
            match (indexed, patterns) with
            | (Second, [ _; index ] | First, [ index; _ ])
              when (not (static_collection collection)) && int_unshadowed ->
                pattern_name index
            | _ -> None
          in
          rendered ~emit index body)
        (function_parts callback)

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

let collection_issues ~module_signatures ~source tree =
  let diagnostics = ref [] in
  let emit name message location =
    diagnostics :=
      M.emit ~source ("react/" ^ name) message location :: !diagnostics
  in
  let array_unshadowed = M.unshadowed_module ~module_signatures "Array" tree in
  let list_unshadowed = M.unshadowed_module ~module_signatures "List" tree in
  let belt_unshadowed = M.unshadowed_module ~module_signatures "Belt" tree in
  let int_unshadowed = M.unshadowed_module ~module_signatures "Int" tree in
  let visitor =
    {
      Ast_iterator.default_iterator with
      expr =
        (fun iterator expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_array values -> List.iter (rendered ~emit None) values
          | _ -> ());
          Option.iter
            (fun (funct, args) ->
              collection_call ~array_unshadowed ~list_unshadowed
                ~belt_unshadowed funct args
              |> inspect_collection ~emit ~int_unshadowed)
            (call_parts expression);
          Ast_iterator.default_iterator.expr iterator expression);
      attribute = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  List.rev !diagnostics

let deduplicate diagnostics =
  List.fold_left
    (fun found (diagnostic : Diagnostic.t) ->
      if
        List.exists
          (fun (previous : Diagnostic.t) ->
            previous.rule = diagnostic.rule && previous.range = diagnostic.range)
          found
      then found
      else diagnostic :: found)
    [] diagnostics
  |> List.rev

let check ?(module_signatures = []) ~source tree =
  let elements = M.elements tree in
  let diagnostics =
    List.concat_map
      (fun element ->
        element_issues element
        |> List.map (fun (name, message) ->
            M.emit ~source ("react/" ^ name) message element.M.location))
      elements
  in
  diagnostics @ collection_issues ~module_signatures ~source tree
  |> Source_range.sort |> deduplicate
