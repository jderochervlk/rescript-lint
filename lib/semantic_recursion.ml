open Semantic_model

let parameter_scope scope parameters =
  List.fold_left
    (fun scope (_, pattern) ->
      bind_pattern scope (pattern_type scope pattern) pattern)
    scope parameters

let value_reference scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name -> resolve scope name.txt
  | _ -> None

let reference_identity scope expression =
  Option.map (fun value -> value.identity) (value_reference scope expression)

let inspect_body scope expression callback =
  Semantic_walk.expression
    { Semantic_walk.nothing with expression = callback }
    scope expression

let parameter_forwarding ~emit scope (binding : Parsetree.value_binding) =
  match pattern_name binding.pvb_pat with
  | None -> ()
  | Some name ->
      let parameters, body = function_parts binding.pvb_expr in
      let nested = parameter_scope scope parameters in
      let target =
        Option.map
          (fun value -> value.identity)
          (Names.find_opt name scope.values)
      in
      let references = ref [] and forwarded = ref [] in
      let inspect current (expression : Parsetree.expression) =
        (match reference_identity current expression with
        | Some identity ->
            references := (identity, expression.pexp_loc) :: !references
        | None -> ());
        match expression.pexp_desc with
        | Pexp_apply { funct; args; partial = false; _ }
          when reference_identity current funct = target
               && target <> None
               && List.length args = List.length parameters ->
            List.iter2
              (fun (parameter_label, parameter) (argument_label, argument) ->
                match
                  (pattern_name parameter, reference_identity current argument)
                with
                | Some name, Some identity when parameter_label = argument_label
                  -> (
                    match Names.find_opt name nested.values with
                    | Some parameter when parameter.identity = identity ->
                        forwarded := argument.pexp_loc :: !forwarded
                    | _ -> ())
                | _ -> ())
              parameters args
        | _ -> ()
      in
      inspect_body nested body inspect;
      List.iter
        (fun (_, pattern) ->
          match pattern_name pattern with
          | None -> ()
          | Some name -> (
              match Names.find_opt name nested.values with
              | Some value ->
                  let uses =
                    List.filter
                      (fun (identity, _) -> identity = value.identity)
                      !references
                  in
                  if
                    uses <> []
                    && List.for_all
                         (fun (_, location) -> List.mem location !forwarded)
                         uses
                  then
                    emit "only-used-in-recursion"
                      ("Parameter " ^ name
                     ^ " is only forwarded unchanged to this recursive \
                        function.")
                      pattern.ppat_loc
              | None -> ()))
        parameters

let eta ~emit ~boundary scope (binding : Parsetree.value_binding) =
  let parameters, body = function_parts binding.pvb_expr in
  let nested = parameter_scope scope parameters in
  let unannotated =
    binding.pvb_attributes = []
    && binding.pvb_expr.pexp_attributes = []
    && match binding.pvb_pat.ppat_desc with Ppat_var _ -> true | _ -> false
  in
  let positional =
    List.for_all
      (fun (label, pattern) ->
        label = Asttypes.Nolabel
        && (match pattern.Parsetree.ppat_desc with
          | Ppat_var _ -> true
          | _ -> false)
        && pattern.ppat_attributes = [])
      parameters
  in
  let async =
    match (unwrap binding.pvb_expr).pexp_desc with
    | Pexp_fun { async; _ } -> async
    | _ -> false
  in
  match body.Parsetree.pexp_desc with
  | Pexp_apply { funct; args; partial = false; _ }
    when parameters <> [] && unannotated && positional && (not async)
         && List.length parameters = List.length args -> (
      let forwarded =
        List.for_all2
          (fun (_, pattern) (label, argument) ->
            label = Asttypes.Nolabel
            && argument.Parsetree.pexp_attributes = []
            &&
            match (pattern_name pattern, value_reference nested argument) with
            | Some name, Some value ->
                Option.fold ~none:false
                  ~some:(fun parameter -> parameter.identity = value.identity)
                  (Names.find_opt name nested.values)
            | _ -> false)
          parameters args
      in
      if forwarded then
        match value_reference nested funct with
        | Some { typ = Function (arguments, _); attributes = []; api; _ }
          when List.length arguments = List.length parameters
               && (match api with Some [ "Stdlib"; _ ] -> false | _ -> true)
               && List.for_all
                    (fun (label, _) -> label = Asttypes.Nolabel)
                    arguments ->
            emit "eta-reduction"
              "This wrapper forwards each positional argument unchanged to a \
               function with the same arity; bind the function directly."
              binding.pvb_loc
        | Some { typ = Unknown; _ } ->
            boundary "eta-reduction"
              "The callee's complete function arity is required before \
               reducing this wrapper."
              binding.pvb_loc
        | _ -> ())
  | _ -> ()

let dependencies scope bindings =
  let identities =
    List.filter_map
      (fun (binding : Parsetree.value_binding) ->
        Option.bind (pattern_name binding.pvb_pat) (fun name ->
            Option.map
              (fun value -> value.identity)
              (Names.find_opt name scope.values)))
      bindings
  in
  List.filter_map
    (fun (binding : Parsetree.value_binding) ->
      Option.bind (pattern_name binding.pvb_pat) (fun name ->
          Option.map
            (fun value ->
              let referenced = ref [] in
              inspect_body scope binding.pvb_expr (fun nested expression ->
                  match reference_identity nested expression with
                  | Some target when List.mem target identities ->
                      referenced := target :: !referenced
                  | _ -> ());
              (value.identity, !referenced))
            (Names.find_opt name scope.values)))
    bindings

let reachable graph source target =
  let rec visit seen node =
    if node = target then true
    else if List.mem node seen then false
    else
      List.exists
        (visit (node :: seen))
        (Option.value ~default:[] (List.assoc_opt node graph))
  in
  visit [] source

let mutual ~emit scope bindings =
  let graph = dependencies scope bindings in
  match (bindings, graph) with
  | first :: _ :: _, (start, _) :: _ ->
      if
        List.exists
          (fun (node, _) ->
            not (reachable graph start node && reachable graph node start))
          graph
      then
        emit "no-redundant-mutual-recursion"
          "These bindings do not form one mutually recursive group; split the \
           independent definitions."
          first.Parsetree.pvb_loc
  | _ -> ()

let list_pattern (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_construct ({ txt = Lident "[]"; _ }, None) -> Some None
  | Ppat_construct
      ( { txt = Lident "::"; _ },
        Some { ppat_desc = Ppat_tuple [ head; tail ]; _ } ) ->
      Some (Some (head, tail))
  | _ -> None

let list_expression expression =
  match (unwrap expression).pexp_desc with
  | Pexp_construct ({ txt = Lident "[]"; _ }, None) -> Some None
  | Pexp_construct
      ( { txt = Lident "::"; _ },
        Some { pexp_desc = Pexp_tuple [ head; tail ]; _ } ) ->
      Some (Some (head, tail))
  | _ -> None

let rec manual_map ~emit scope (binding : Parsetree.value_binding) =
  let parameters, body = function_parts binding.pvb_expr in
  match
    (pattern_name binding.pvb_pat, parameters, body.Parsetree.pexp_desc)
  with
  | ( Some name,
      [ (_, parameter) ],
      Pexp_match (subject, [ empty_case; cons_case ]) ) ->
      let nested = parameter_scope scope parameters in
      let parameter_id =
        Option.bind (pattern_name parameter) (fun name ->
            Option.map
              (fun value -> value.identity)
              (Names.find_opt name nested.values))
      in
      if
        reference_identity nested subject = parameter_id
        && parameter_id <> None && empty_case.pc_guard = None
        && cons_case.pc_guard = None
        && list_pattern empty_case.pc_lhs = Some None
        && list_expression empty_case.pc_rhs = Some None
      then manual_map_cons ~emit scope nested name binding.pvb_loc cons_case
  | _ -> ()

and manual_map_cons ~emit outer scope name location (case : Parsetree.case) =
  match (list_pattern case.pc_lhs, list_expression case.pc_rhs) with
  | Some (Some (head_pattern, tail_pattern)), Some (Some (mapped, rest)) -> (
      let nested = bind_pattern scope (List Unknown) case.pc_lhs in
      let callee =
        Option.map
          (fun value -> value.identity)
          (Names.find_opt name outer.values)
      in
      let tail =
        Option.bind (pattern_name tail_pattern) (fun name ->
            Option.map
              (fun value -> value.identity)
              (Names.find_opt name nested.values))
      in
      match rest.pexp_desc with
      | Pexp_apply { funct; args = [ (Nolabel, argument) ]; partial = false; _ }
        when reference_identity nested funct = callee
             && callee <> None
             && reference_identity nested argument = tail
             && tail <> None && pure nested mapped ->
          let head =
            Option.bind (pattern_name head_pattern) (fun name ->
                Option.map
                  (fun value -> value.identity)
                  (Names.find_opt name nested.values))
          in
          let uses_tail = ref false and uses_head = ref false in
          inspect_body nested mapped (fun current expression ->
              let id = reference_identity current expression in
              if id = tail then uses_tail := true;
              if id = head then uses_head := true);
          if !uses_head && not !uses_tail then
            emit "prefer-standard-combinator"
              "This pure list recursion has List.map semantics; use List.map \
               with the element transformation."
              location
      | _ -> ())
  | _ -> ()

let check ~emit ~boundary scope flag bindings =
  if flag = Asttypes.Nonrecursive then
    List.iter (eta ~emit ~boundary scope) bindings;
  if flag = Asttypes.Recursive then (
    List.iter (parameter_forwarding ~emit scope) bindings;
    mutual ~emit scope bindings;
    List.iter (manual_map ~emit scope) bindings)
