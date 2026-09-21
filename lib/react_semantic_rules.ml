module Names = Set.Make (String)

let rule_ids =
  [
    "react/no-unstable-nested-components";
    "react/jsx-no-constructed-context-values";
    "react/exhaustive-deps";
    "react/no-new-prop-value";
  ]

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
    }

let initial context =
  let scope = Semantic_model.initial context in
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

let inspect_props ~source emit scope element =
  List.iter
    (fun property ->
      match property.Jsx_model.value with
      | Some value
        when allocated value
             && not (List.mem property.name [ "children"; "key"; "ref" ]) ->
          emit
            (Jsx_model.emit ~source "react/no-new-prop-value"
               ("This " ^ property.name
              ^ " prop is allocated during every render.")
               property.location)
      | _ -> ())
    element.Jsx_model.props;
  if provider scope element then
    match Jsx_model.prop "value" element with
    | Value expression when allocated expression ->
        emit
          (Jsx_model.emit ~source "react/jsx-no-constructed-context-values"
             "This context value is allocated during every render; provide a \
              stable value."
             expression.pexp_loc)
    | _ -> ()

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

let rec access expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_ident ({ txt = Lident name; _ } as identifier) ->
      Some (identifier, name, [], [])
  | Pexp_field (parent, field) ->
      Option.map
        (fun (identifier, name, fields, children) ->
          let member = Longident.last field.txt in
          ( identifier,
            name ^ "." ^ member,
            fields @ [ member ],
            parent :: children ))
        (access parent)
  | _ -> None

let access_key identity fields = String.concat "." (identity :: fields)

let dependency_name scope expression =
  Option.bind (access expression) (fun (identifier, _, fields, _) ->
      Option.map
        (fun value -> access_key value.Semantic_model.identity fields)
        (Semantic_model.resolve scope identifier.txt))

let dependencies scope expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_array values | Pexp_tuple values ->
      Some (List.filter_map (dependency_name scope) values |> Names.of_list)
  | _ -> None

let captured ~scope ~global callback =
  let references = ref [] in
  let consumed = ref [] in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression =
        (fun inner expression ->
          if not (List.exists (fun child -> child == expression) !consumed) then
            match access expression with
            | Some (identifier, name, fields, children) -> (
                consumed := children @ !consumed;
                match Semantic_model.resolve inner identifier.txt with
                | Some value when not (Names.mem value.identity global) -> (
                    match Semantic_model.resolve scope identifier.txt with
                    | Some outer when outer.identity = value.identity ->
                        references :=
                          (name, access_key value.identity fields)
                          :: !references
                    | _ -> ())
                | _ -> ())
            | _ -> ());
    }
  in
  Semantic_walk.iter callbacks scope
    (Parser.Implementation [ Ast_helper.Str.eval callback ]);
  List.sort_uniq compare !references

let covered dependencies identity =
  Names.exists
    (fun dependency ->
      identity = dependency
      || String.starts_with ~prefix:(dependency ^ ".") identity)
    dependencies

let rec callback_body scope seen expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_ident identifier -> (
      match Semantic_model.resolve scope identifier.txt with
      | Some value when not (Names.mem value.identity seen) ->
          Option.fold ~none:expression
            ~some:(callback_body scope (Names.add value.identity seen))
            value.expression
      | _ -> expression)
  | _ -> expression

let inspect_dependencies ~source emit ~global scope expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_apply
      { funct; args = (Nolabel, callback) :: arguments; partial = false; _ }
    -> (
      match canonical scope funct with
      | Some [ "React"; name ] when List.mem name hooks ->
          let deps =
            match arguments with
            | [ (Nolabel, values) ] -> dependencies scope values
            | [] when String.ends_with ~suffix:"0" name -> Some Names.empty
            | _ -> None
          in
          Option.iter
            (fun dependencies ->
              let callback = callback_body scope Names.empty callback in
              let missing =
                captured ~scope ~global callback
                |> List.filter (fun (_, identity) ->
                    not (covered dependencies identity))
              in
              if missing <> [] then
                emit
                  (Jsx_model.emit ~source "react/exhaustive-deps"
                     ("Include captured reactive values in the dependency \
                       list: "
                     ^ String.concat ", " (List.map fst missing)
                     ^ ".")
                     expression.pexp_loc))
            deps
      | _ -> ())
  | _ -> ()

let stable_hook_values scope tree =
  let stable = ref Names.empty in
  let add pattern =
    let scope =
      Semantic_model.bind_pattern Semantic_model.empty Unknown pattern
    in
    Semantic_model.Names.iter
      (fun _ value -> stable := Names.add value.Semantic_model.identity !stable)
      scope.values
  in
  let callbacks =
    {
      Semantic_walk.nothing with
      bindings =
        (fun scope _ bindings ->
          List.iter
            (fun (binding : Parsetree.value_binding) ->
              match (Semantic_model.unwrap binding.pvb_expr).pexp_desc with
              | Pexp_apply { funct; _ } -> (
                  match (canonical scope funct, binding.pvb_pat.ppat_desc) with
                  | ( Some [ "React"; ("useState" | "useReducer") ],
                      Ppat_tuple [ _; setter ] ) ->
                      add setter
                  | Some [ "React"; "useRef" ], Ppat_var _ ->
                      add binding.pvb_pat
                  | _ -> ())
              | _ -> ())
            bindings);
    }
  in
  Semantic_walk.iter callbacks scope tree;
  !stable

type context = {
  render : bool;
  in_function : bool;
  global : Names.t;
  stable : Names.t;
}

let rec iterator ~source ~emit ~scope_at context =
  {
    Ast_iterator.default_iterator with
    expr =
      (fun _ expression -> visit ~source ~emit ~scope_at context expression);
    value_binding =
      (fun _ binding -> binding_visit ~source ~emit ~scope_at context binding);
    attribute = (fun _ _ -> ());
    attributes = (fun _ _ -> ());
  }

and visit ~source ~emit ~scope_at context expression =
  let scope = scope_at expression in
  let global =
    if context.in_function then context.global
    else Names.union context.stable (globals scope)
  in
  inspect_dependencies ~source emit ~global scope expression;
  if context.render then
    Option.iter
      (inspect_props ~source emit scope)
      (Jsx_model.of_expression expression);
  let context =
    match expression.Parsetree.pexp_desc with
    | Pexp_fun _ -> { context with render = false; in_function = true; global }
    | _ -> context
  in
  Ast_iterator.default_iterator.expr
    (iterator ~source ~emit ~scope_at context)
    expression

and binding_visit ~source ~emit ~scope_at context
    (binding : Parsetree.value_binding) =
  if component binding.pvb_attributes then (
    if context.render then
      emit
        (Jsx_model.emit ~source "react/no-unstable-nested-components"
           "Move this component definition outside the rendering component."
           binding.pvb_loc);
    let global =
      Names.union context.stable (globals (scope_at binding.pvb_expr))
    in
    component_body ~source ~emit ~scope_at
      { context with render = true; in_function = true; global }
      binding.pvb_expr)
  else visit ~source ~emit ~scope_at context binding.pvb_expr

and component_body ~source ~emit ~scope_at context expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_fun { arity; _ } ->
      parameters ~source ~emit ~scope_at context
        (Option.value ~default:1 arity)
        expression
  | Pexp_apply
      { funct; args = (Nolabel, callback) :: arguments; partial = false; _ }
    when List.mem
           (canonical (scope_at expression) funct)
           [ Some [ "React"; "memo" ]; Some [ "React"; "forwardRef" ] ] ->
      component_body ~source ~emit ~scope_at context callback;
      List.iter
        (fun (_, argument) ->
          visit ~source ~emit ~scope_at { context with render = false } argument)
        arguments
  | _ -> visit ~source ~emit ~scope_at context expression

and parameters ~source ~emit ~scope_at context remaining expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_fun { default; rhs; _ } when remaining > 0 ->
      Option.iter (visit ~source ~emit ~scope_at context) default;
      parameters ~source ~emit ~scope_at context (remaining - 1) rhs
  | _ -> visit ~source ~emit ~scope_at context expression

let check ?(context = Semantic_model.default_context) ~source tree =
  let scope = initial context in
  let scope_at = expressions tree scope in
  let stable = stable_hook_values scope tree in
  let findings = ref [] in
  let emit finding = findings := finding :: !findings in
  let visitor =
    iterator ~source ~emit ~scope_at
      {
        render = false;
        in_function = false;
        global = Names.union stable (globals scope);
        stable;
      }
  in
  (match tree with
  | Parser.Implementation structure -> visitor.structure visitor structure
  | Interface signature -> visitor.signature visitor signature);
  Source_range.sort (List.rev !findings)
