let members =
  [
    "parseOrThrow";
    "parseExn";
    "parseExnWithReviver";
    "stringifyAny";
    "stringifyAnyWithIndent";
    "stringifyAnyWithReplacer";
    "stringifyAnyWithReplacerAndIndent";
    "stringifyAnyWithFilter";
    "stringifyAnyWithFilterAndIndent";
  ]

let annotated_paths =
  List.concat_map
    (fun root -> List.map (fun member -> root @ [ member ]) members)
    [ [ "JSON" ]; [ "Stdlib"; "JSON" ]; [ "Stdlib_JSON" ] ]

let callable path =
  if List.mem path annotated_paths then Throws_scope.Annotated Any
  else Throws_scope.Plain

let module_values path opaque names =
  if opaque then Throws_scope.unknown
  else
    List.fold_left
      (fun scope name ->
        Throws_scope.add_value name (callable (path @ [ name ])) scope)
      Throws_scope.empty names

let rec insert path nested scope =
  if Throws_scope.is_opaque scope then scope
  else
    match path with
    | [] -> nested
    | name :: rest ->
        let previous =
          Option.value ~default:Throws_scope.empty
            (Throws_scope.module_scope scope [ name ])
        in
        Throws_scope.add_module name (insert rest nested previous) scope

let scope =
  let runtime =
    List.fold_left
      (fun scope (path, opaque, names) ->
        insert path (module_values path opaque names) scope)
      Throws_scope.empty Banned_runtime_data.modules
  in
  let opened =
    Option.value ~default:Throws_scope.empty
      (Throws_scope.module_scope runtime [ "Stdlib" ])
  in
  Throws_scope.overlay Throws_scope.initial
    (Throws_scope.overlay runtime opened)
