let rule_ids =
  [ "simplify-boolean-expression"; "no-useless-concat"; "approx-constant" ]

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

let simplify_boolean ~source (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse (_, left, Some right) -> opposite_booleans left right
  | Pexp_match (_, [ left; right ]) -> boolean_switch left right
  | Pexp_apply _ ->
      Option.fold ~none:false ~some:boolean_binary (binary ~source expression)
      || Option.fold ~none:false
           ~some:(fun inner -> negated ~source inner <> None)
           (negated ~source expression)
  | _ -> false

let useless_concat ~source expression =
  match binary ~source expression with
  | Some ("++", left, right) -> (
      match (string_literal left, string_literal right) with
      | Some _, Some _ | Some "", _ | _, Some "" -> true
      | _ -> false)
  | _ -> false

let constants =
  [
    ("e", 2.718281828459045);
    ("ln2", 0.6931471805599453);
    ("ln10", 2.302585092994046);
    ("log2e", 1.4426950408889634);
    ("log10e", 0.4342944819032518);
    ("pi", 3.141592653589793);
    ("sqrt1_2", 0.7071067811865476);
    ("sqrt2", 1.4142135623730951);
  ]

let approximate value =
  List.find_opt
    (fun (_, constant) -> Float.abs (Float.abs value -. constant) <= 0.000005)
    constants
  |> Option.map (fun (name, _) ->
      let sign = if value < 0. then "the negative of " else "" in
      "This literal approximates " ^ sign ^ "Math.Constants." ^ name ^ ".")

let approximate_constant (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_float (value, None)) ->
      Option.bind (Float.of_string_opt value) approximate
  | _ -> None

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

let inspect ~source expression =
  let boolean =
    if simplify_boolean ~source expression then
      Some
        ( "simplify-boolean-expression",
          "This boolean expression can be simplified." )
    else None
  in
  let concat =
    if useless_concat ~source expression then
      Some
        ( "no-useless-concat",
          "Avoid concatenating string literals or an empty string." )
    else None
  in
  let constant =
    Option.map
      (fun message -> ("approx-constant", message))
      (approximate_constant expression)
  in
  List.filter_map Fun.id [ boolean; concat; constant ]
  |> List.map (fun (rule, message) ->
      diagnostic ~source expression rule message)

let check ~(source : Source.t) tree =
  let diagnostics = ref [] in
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      expr =
        (fun iterator expression ->
          diagnostics :=
            List.rev_append (inspect ~source expression) !diagnostics;
          default.expr iterator expression);
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation structure -> visitor.structure visitor structure
  | Interface signature -> visitor.signature visitor signature);
  List.rev !diagnostics |> Source_range.sort
