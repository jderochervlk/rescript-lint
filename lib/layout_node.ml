type t = { loc : Location.t; before : bool; after : bool }

let plain loc = { loc; before = false; after = false }

let annotated attributes =
  List.exists
    (fun ((name : string Location.loc), _) ->
      (not (String.starts_with ~prefix:"res." name.txt))
      && not (String.starts_with ~prefix:"ocaml." name.txt))
    attributes

let expression_location (expr : Parsetree.expression) =
  Option.value ~default:expr.pexp_loc
    (List.find_map
       (fun ((name : string Location.loc), _) ->
         if name.txt = "res.braces" then Some name.loc else None)
       expr.pexp_attributes)

let rec expression (expr : Parsetree.expression) =
  let node = plain (expression_location expr) in
  match expr.pexp_desc with
  | Pexp_match _ -> { node with before = true; after = true }
  | Pexp_apply
      { funct = { pexp_desc = Pexp_ident { txt = Lident "->"; _ }; _ }; _ } ->
      { node with after = true }
  | Pexp_constraint (inner, _) ->
      let inner = expression inner in
      { inner with loc = node.loc }
  | _ -> node

let binding (binding : Parsetree.value_binding) =
  let value = expression binding.pvb_expr in
  {
    value with
    loc = binding.pvb_loc;
    before = value.before || annotated binding.pvb_attributes;
  }

let bindings bindings =
  match List.map binding bindings with
  | [] -> plain Location.none
  | first :: rest ->
      List.fold_left
        (fun group node ->
          {
            loc = { group.loc with loc_end = node.loc.loc_end };
            before = group.before || node.before;
            after = group.after || node.after;
          })
        first rest

let value (description : Parsetree.value_description) =
  {
    loc = description.pval_loc;
    before = annotated description.pval_attributes;
    after = description.pval_prim <> [];
  }

let structure (item : Parsetree.structure_item) =
  let node =
    match item.pstr_desc with
    | Pstr_primitive description -> value description
    | Pstr_value (_, values) -> bindings values
    | Pstr_eval (expr, _) -> expression expr
    | _ -> plain item.pstr_loc
  in
  { node with loc = item.pstr_loc }

let signature (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value description -> { (value description) with loc = item.psig_loc }
  | _ -> plain item.psig_loc

let first (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_sequence (head, _) -> expression head
  | Pexp_let (_, values, _) -> bindings values
  | Pexp_letmodule (_, value, _) ->
      plain { expr.pexp_loc with loc_end = value.pmod_loc.loc_end }
  | Pexp_letexception (value, _) ->
      plain { expr.pexp_loc with loc_end = value.pext_loc.loc_end }
  | Pexp_open (_, value, _) ->
      plain { expr.pexp_loc with loc_end = value.loc.loc_end }
  | _ -> expression expr
