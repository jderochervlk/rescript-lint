let attribute name attributes =
  List.exists (fun (key, _) -> key.Location.txt = name) attributes

let ternary (expression : Parsetree.expression) =
  attribute "res.ternary" expression.pexp_attributes

let rec unit_body (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_construct ({ txt = Lident "()"; _ }, None) -> true
  | Pexp_constraint (body, _) -> unit_body body
  | _ -> false

let boolean_pattern (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_construct ({ txt = Lident "true"; _ }, None) -> Some true
  | Ppat_construct ({ txt = Lident "false"; _ }, None) -> Some false
  | _ -> None

let boolean_cases (first : Parsetree.case) (second : Parsetree.case) =
  first.pc_guard = None && second.pc_guard = None
  &&
  match (boolean_pattern first.pc_lhs, boolean_pattern second.pc_lhs) with
  | Some left, Some right -> left <> right
  | _ -> false

let irrefutable (case : Parsetree.case) =
  case.pc_guard = None
  &&
  match case.pc_lhs.ppat_desc with
  | Ppat_any | Ppat_var _ -> true
  | _ -> false

let negated ~source (condition : Parsetree.expression) =
  match condition.pexp_desc with
  | Pexp_apply { funct; args = [ (Nolabel, _) ]; partial = false; _ } ->
      Expression_rules.operator ~source funct = Some "not"
  | _ -> false

let complete_template ~(source : Source.t) (expression : Parsetree.expression) =
  let start = expression.pexp_loc.loc_start.pos_cnum in
  let finish = expression.pexp_loc.loc_end.pos_cnum in
  start >= 0
  && finish <= String.length source.text
  && finish - start >= 2
  && source.text.[start] = '`'
  && source.text.[finish - 1] = '`'

let line_count text =
  if text = "" then 0
  else
    let newlines =
      String.fold_left
        (fun total c -> if c = '\n' then total + 1 else total)
        0 text
    in
    newlines + if text.[String.length text - 1] = '\n' then 0 else 1

let file_start =
  let position =
    { Lexing.dummy_pos with pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  { Location.loc_start = position; loc_end = position; loc_ghost = false }
