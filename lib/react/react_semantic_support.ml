module Names = Set.Make (String)

let component attributes =
  List.exists
    (fun (name, _) ->
      List.mem name.Location.txt
        [ "react.component"; "react.componentWithProps"; "jsx.component" ])
    attributes

let hooks =
  List.concat_map
    (fun prefix ->
      prefix :: List.init 8 (fun index -> prefix ^ string_of_int index))
    [ "useEffect"; "useLayoutEffect"; "useMemo"; "useCallback" ]

let react_value names =
  Semantic_model.
    {
      identity = "react:" ^ String.concat "." names;
      canonical = Some names;
      typ = Unknown;
      api = None;
      pure = false;
      expression = None;
      attributes = [];
      declaration_origin = External;
    }

let initial context =
  let scope = Semantic_runtime.initial_scope context in
  match Semantic_model.module_path scope [ "React" ] with
  | Some _ -> scope
  | None ->
      let react =
        List.fold_left
          (fun scope name ->
            Semantic_model.add_value name (react_value [ "React"; name ]) scope)
          { Semantic_model.empty with origin = Some [ "React" ] }
          (hooks
          @ [
              "createContext";
              "useState";
              "useReducer";
              "useRef";
              "memo";
              "forwardRef";
            ])
      in
      let context =
        Semantic_model.add_value "provider"
          (react_value [ "React"; "Context"; "provider" ])
          { Semantic_model.empty with origin = Some [ "React"; "Context" ] }
      in
      Semantic_model.add_module "React"
        (Semantic_model.add_module "Context" context react)
        scope

let canonical scope expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_ident identifier ->
      Option.bind (Semantic_model.resolve scope identifier.txt) (fun value ->
          value.canonical)
  | _ -> None

let allocated expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_array _ | Pexp_record _ | Pexp_tuple _ | Pexp_fun _ -> true
  | _ -> false

let rec longident = function
  | [] -> Longident.Lident ""
  | [ name ] -> Longident.Lident name
  | names -> (
      match List.rev names with
      | name :: parent -> Longident.Ldot (longident (List.rev parent), name)
      | [] -> Longident.Lident "")

let provider scope element =
  let identifier = longident (element.Jsx_model.name @ [ "make" ]) in
  match Semantic_model.resolve scope identifier with
  | Some { expression = Some value; _ } -> (
      match (Semantic_model.unwrap value).pexp_desc with
      | Pexp_apply { funct; _ } ->
          canonical scope funct = Some [ "React"; "Context"; "provider" ]
      | _ -> false)
  | _ -> false

let globals scope =
  Semantic_model.Names.bindings scope.Semantic_model.values
  |> List.map (fun (_, value) -> value.Semantic_model.identity)
  |> Names.of_list

let expressions tree scope =
  let values = ref [] in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression =
        (fun scope expression -> values := (expression, scope) :: !values);
      bindings =
        (fun scope _ bindings ->
          List.iter
            (fun (binding : Parsetree.value_binding) ->
              values := (binding.pvb_expr, scope) :: !values)
            bindings);
    }
  in
  Semantic_walk.iter callbacks scope tree;
  fun expression ->
    match
      List.find_opt (fun (candidate, _) -> candidate == expression) !values
    with
    | Some (_, scope) -> scope
    | None -> scope

type context = {
  render : bool;
  in_function : bool;
  global : Names.t;
  stable : Names.t;
}
