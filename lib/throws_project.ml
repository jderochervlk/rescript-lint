module Names = Set.Make (String)

let metadata project =
  List.filter
    (fun unit ->
      match unit.Project_files.tree with
      | Parser.Interface _ -> true
      | Implementation _ -> not (Project_files.has_interface project unit))
    project.Project_files.units

let dependencies units source tree =
  let names = List.map (fun unit -> unit.Project_files.name) units in
  let referenced tree =
    Throws_dependencies.modules ~project_modules:names tree
  in
  let rec visit seen = function
    | [] -> seen
    | name :: rest when Names.mem name seen -> visit seen rest
    | name :: rest ->
        let next =
          match
            List.find_opt (fun unit -> unit.Project_files.name = name) units
          with
          | None -> []
          | Some unit -> referenced unit.tree
        in
        visit (Names.add name seen) (next @ rest)
  in
  visit Names.empty
    (Project_files.module_name source.Source.filename :: referenced tree)

let populate units scope =
  List.fold_left
    (fun (scope, errors) unit ->
      let exports, diagnostics =
        No_unhandled_throws.exports ~scope ~source:unit.Project_files.source
          unit.tree
      in
      ( Throws_scope.add_module unit.name exports scope,
        (unit.name, diagnostics) :: errors ))
    (scope, []) units

let index units =
  let initial =
    List.fold_left
      (fun scope unit ->
        Throws_scope.add_module unit.Project_files.name Throws_scope.empty scope)
      Throws_scope.initial units
  in
  let rec settle remaining scope =
    let next, errors = populate units scope in
    if remaining = 0 || next = scope then (next, errors)
    else settle (remaining - 1) next
  in
  settle (List.length units) initial

let exception_pairs project scope =
  List.concat_map
    (fun unit ->
      match unit.Project_files.tree with
      | Parser.Implementation _ when Project_files.has_interface project unit ->
          let implementation, _ =
            No_unhandled_throws.exports ~scope ~source:unit.source unit.tree
          in
          let private_exceptions =
            Throws_scope.exception_bindings implementation
          in
          let public =
            Option.value ~default:Throws_scope.empty
              (Throws_scope.module_scope scope [ unit.name ])
          in
          List.filter_map
            (fun (path, identity) ->
              Option.map
                (fun implementation -> (implementation, identity))
                (List.assoc_opt path private_exceptions))
            (Throws_scope.exception_bindings public)
      | _ -> [])
    project.Project_files.units

let aliases pairs =
  let neighbors identity =
    List.filter_map
      (fun (left, right) ->
        if identity = left then Some right
        else if identity = right then Some left
        else None)
      pairs
  in
  let rec connected seen = function
    | [] -> seen
    | identity :: rest when Names.mem identity seen -> connected seen rest
    | identity :: rest ->
        connected (Names.add identity seen) (neighbors identity @ rest)
  in
  let identities =
    List.concat_map (fun (left, right) -> [ left; right ]) pairs
    |> List.sort_uniq String.compare
  in
  List.map
    (fun identity ->
      let canonical =
        Option.value ~default:identity
          (Names.min_elt_opt (connected Names.empty [ identity ]))
      in
      (identity, canonical))
    identities

let check ~project ~source tree =
  let units = metadata project in
  let relevant = dependencies units source tree in
  let active =
    No_unhandled_throws.has_annotations tree
    || List.exists
         (fun unit ->
           Names.mem unit.Project_files.name relevant
           && No_unhandled_throws.has_annotations unit.tree)
         units
  in
  if not active then Ok []
  else
    let scope, errors = index units in
    let errors =
      List.concat_map
        (fun (name, errors) -> if Names.mem name relevant then errors else [])
        errors
    in
    match Source_range.sort errors with
    | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
    | [] ->
        let scope =
          Throws_scope.with_exception_aliases
            (aliases (exception_pairs project scope))
            scope
        in
        No_unhandled_throws.check ~scope ~source tree
