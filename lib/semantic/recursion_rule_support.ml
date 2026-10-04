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
