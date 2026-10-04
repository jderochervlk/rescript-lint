let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) -> unwrap inner
  | _ -> expression

let boolean expression =
  match (unwrap expression).pexp_desc with
  | Pexp_construct ({ txt = Lident "true"; _ }, None) -> Some true
  | Pexp_construct ({ txt = Lident "false"; _ }, None) -> Some false
  | _ -> None

let string_literal expression =
  match (unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_string (value, None)) -> Some value
  | _ -> None

let source_token ~(source : Source.t) (expression : Parsetree.expression) token
    =
  let range =
    Source_range.of_location ~source:source.text expression.pexp_loc
  in
  let start = range.start.byte_offset in
  let length = range.finish.byte_offset - start in
  start >= 0
  && length = String.length token
  && start + length <= String.length source.text
  && String.sub source.text start length = token

let operator ~source expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_ident { txt = Lident name; _ } ->
      let token = if name = "not" then "!" else name in
      if source_token ~source expression token then Some name else None
  | _ -> None

let binary ~source (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_apply
      {
        funct;
        args = [ (Nolabel, left); (Nolabel, right) ];
        partial = false;
        _;
      } ->
      Option.map (fun name -> (name, left, right)) (operator ~source funct)
  | _ -> None

let negated ~source expression =
  match (unwrap expression).pexp_desc with
  | Pexp_apply { funct; args = [ (Nolabel, value) ]; partial = false; _ }
    when operator ~source funct = Some "not" ->
      Some value
  | _ -> None

let opposite_booleans left right =
  match (boolean left, boolean right) with
  | Some left, Some right -> left <> right
  | _ -> false

let pattern_boolean (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_construct ({ txt = Lident "true"; _ }, None) -> Some true
  | Ppat_construct ({ txt = Lident "false"; _ }, None) -> Some false
  | _ -> None

let boolean_switch (left : Parsetree.case) (right : Parsetree.case) =
  match (pattern_boolean left.pc_lhs, pattern_boolean right.pc_lhs) with
  | Some first, Some second ->
      first <> second && left.pc_guard = None && right.pc_guard = None
      && opposite_booleans left.pc_rhs right.pc_rhs
  | _ -> false

let boolean_binary = function
  | "==", left, right
  | "===", left, right
  | "!=", left, right
  | "!==", left, right ->
      boolean left <> None || boolean right <> None
  | "&&", left, right -> boolean left = Some true || boolean right = Some true
  | "||", left, right -> boolean left = Some false || boolean right = Some false
  | _ -> false

let diagnostic ~source expression rule message =
  Diagnostic.
    {
      filename = source.Source.filename;
      rule;
      message;
      help = None;
      symbol = None;
      fixes = [];
      range =
        Source_range.of_location ~source:source.text
          expression.Parsetree.pexp_loc;
    }
