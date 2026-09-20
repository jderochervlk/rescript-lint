module Ids = Set.Make (String)

type t = All | Named of Ids.t

let empty = Named Ids.empty

let union left right =
  match (left, right) with
  | All, _ | _, All -> All
  | Named left, Named right -> Named (Ids.union left right)

let rec irrefutable (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_any | Ppat_var _ -> true
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) -> irrefutable inner
  | Ppat_tuple items -> List.for_all irrefutable items
  | Ppat_or (left, right) -> irrefutable left || irrefutable right
  | _ -> false

let constructor scope name payload =
  if not (Option.fold ~none:true ~some:irrefutable payload) then empty
  else
    match
      Option.bind
        (Throws_annotation.path name.Location.txt)
        (Throws_scope.exception_id scope)
    with
    | Some identity -> Named (Ids.singleton identity)
    | None -> empty

let rec pattern scope (value : Parsetree.pattern) =
  match value.ppat_desc with
  | Ppat_any | Ppat_var _ -> All
  | Ppat_construct (name, payload) -> constructor scope name payload
  | Ppat_or (left, right) -> union (pattern scope left) (pattern scope right)
  | _ -> wrapped scope value

and wrapped scope value =
  match value.Parsetree.ppat_desc with
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) -> pattern scope inner
  | _ -> empty

let rec exception_pattern scope (value : Parsetree.pattern) =
  match value.ppat_desc with
  | Ppat_exception inner -> pattern scope inner
  | Ppat_or (left, right) ->
      union (exception_pattern scope left) (exception_pattern scope right)
  | Ppat_alias (inner, _) | Ppat_constraint (inner, _) ->
      exception_pattern scope inner
  | _ -> empty

let cases coverage scope cases =
  List.fold_left
    (fun result (case : Parsetree.case) ->
      match case.pc_guard with
      | Some _ -> result
      | None -> union result (coverage scope case.pc_lhs))
    empty cases

let catches = cases pattern
let switches = cases exception_pattern

let missing handlers = function
  | Throws_scope.Any -> (
      match handlers with
      | All -> []
      | Named _ -> [ "unknown exceptions (a catch-all is required)" ])
  | Named exceptions ->
      List.filter_map
        (fun (exception_ : Throws_scope.exception_ref) ->
          match handlers with
          | All -> None
          | Named ids ->
              if Ids.mem exception_.identity ids then None
              else Some exception_.display)
        exceptions
