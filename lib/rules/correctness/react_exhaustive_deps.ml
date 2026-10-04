let metadata =
  Rule_metadata.
    {
      id = "react/exhaustive-deps";
      category = Correctness;
      enabled_by_default = false;
    }

open React_semantic_support

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
