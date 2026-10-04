let metadata =
  Rule_metadata.
    {
      id = "no-redundant-mutual-recursion";
      category = Style;
      enabled_by_default = false;
    }

open Semantic_model
open Recursion_rule_support

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
