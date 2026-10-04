open Semantic_model

let runtime_value path =
  {
    (unknown_value Location.none) with
    identity = "runtime:" ^ String.concat "." path;
    api = Some path;
    canonical = Some path;
  }

let module_values path opaque names previous =
  List.fold_left
    (fun scope name -> add_value name (runtime_value (path @ [ name ])) scope)
    { previous with origin = Some path; opaque }
    names

let rec insert path update scope =
  match path with
  | [] -> update scope
  | name :: rest ->
      let previous =
        Option.value ~default:empty (Names.find_opt name scope.modules)
      in
      add_module name (insert rest update previous) scope

let seed entries =
  List.fold_left
    (fun scope (path, opaque, names) ->
      insert path (module_values path opaque names) scope)
    empty entries

let rec rebase path scope =
  {
    scope with
    origin = Some path;
    values =
      Names.mapi (fun name _ -> runtime_value (path @ [ name ])) scope.values;
    modules =
      Names.mapi
        (fun name nested -> rebase (path @ [ name ]) nested)
        scope.modules;
  }

let scope =
  let root = seed Banned_runtime_data.modules in
  (* Preserve the original implementation-spelling ban, despite its .resi mask. *)
  let root =
    insert [ "Primitive_object" ]
      (add_value "magic" (runtime_value [ "Primitive_object"; "magic" ]))
      root
  in
  match Names.find_opt "Stdlib" root.modules with
  | None -> root
  | Some standard -> overlay root (rebase [] standard)
