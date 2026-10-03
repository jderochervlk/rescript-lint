let rule_ids =
  [
    "no-obj-external";
    "no-mutable-record-field";
    "no-record-mutation";
    "no-while";
    "no-for";
    "no-empty-loop";
    "no-negated-condition";
    "no-nested-ternary";
    "prefer-if";
    "no-single-case-switch";
    "no-unnecessary-template";
    "max-lines";
    "max-switch-cases";
  ]

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

let inspect_if ~source emit expression condition yes no =
  if negated ~source condition then
    emit "no-negated-condition"
      "Prefer a positive condition and exchange the branches."
      expression.Parsetree.pexp_loc;
  if
    ternary expression
    && List.exists
         (fun child -> ternary (Semantic_model.unwrap child))
         [ condition; yes; no ]
  then
    emit "no-nested-ternary" "Extract the nested ternary or use a switch."
      expression.pexp_loc

let inspect_loop emit rule body location =
  emit rule
    "Prefer a collection operation or an explicit recursive function to this \
     loop."
    location;
  if unit_body body then
    emit "no-empty-loop" "This loop has an empty body." location

let complete_template ~(source : Source.t) (expression : Parsetree.expression) =
  let start = expression.pexp_loc.loc_start.pos_cnum in
  let finish = expression.pexp_loc.loc_end.pos_cnum in
  start >= 0
  && finish <= String.length source.text
  && finish - start >= 2
  && source.text.[start] = '`'
  && source.text.[finish - 1] = '`'

let inspect_switch ~max_switch_cases emit location cases =
  if List.length cases > max_switch_cases then
    emit "max-switch-cases"
      (Printf.sprintf "This switch has %d cases; the configured maximum is %d."
         (List.length cases) max_switch_cases)
      location;
  match cases with
  | [ first; second ] when boolean_cases first second ->
      emit "prefer-if"
        "Prefer an if expression for this two-case boolean switch." location
  | [ case ] when irrefutable case ->
      emit "no-single-case-switch"
        "Replace this irrefutable single-case switch with a binding or \
         sequence."
        location
  | _ -> ()

let inspect_control ~source ~max_switch_cases emit
    (expression : Parsetree.expression) =
  let location = expression.pexp_loc in
  match expression.pexp_desc with
  | Pexp_while (_, body) -> inspect_loop emit "no-while" body location
  | Pexp_for (_, _, _, _, body) -> inspect_loop emit "no-for" body location
  | Pexp_ifthenelse (condition, yes, Some no) ->
      inspect_if ~source emit expression condition yes no
  | Pexp_match (_, cases) ->
      inspect_switch ~max_switch_cases emit location cases
  | _ -> ()

let inspect_expression ~source emit (expression : Parsetree.expression) =
  let location = expression.pexp_loc in
  match expression.pexp_desc with
  | Pexp_setfield _ ->
      emit "no-record-mutation"
        "Prefer constructing an updated record to assigning a field." location
  | Pexp_constant (Pconst_string (_, Some "js"))
    when attribute "res.template" expression.pexp_attributes
         && complete_template ~source expression
         && not (attribute "res.taggedTemplate" expression.pexp_attributes) ->
      emit "no-unnecessary-template"
        "Prefer an ordinary string when no interpolation is needed." location
  | _ -> ()

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

let inspect_external emit (value : Parsetree.value_description) =
  if
    attribute "obj" value.pval_attributes
    || attribute "bs.obj" value.pval_attributes
  then
    emit "no-obj-external"
      "Prefer a record or object expression to an @obj external." value.pval_loc

let iterator ~source ~max_switch_cases emit =
  let default = Ast_iterator.default_iterator in
  {
    default with
    expr =
      (fun visitor expression ->
        inspect_control ~source ~max_switch_cases emit expression;
        inspect_expression ~source emit expression;
        default.expr visitor expression);
    value_description =
      (fun visitor value ->
        inspect_external emit value;
        default.value_description visitor value);
    label_declaration =
      (fun visitor field ->
        if field.Parsetree.pld_mutable = Asttypes.Mutable then
          emit "no-mutable-record-field" "Prefer an immutable record field."
            field.pld_loc;
        default.label_declaration visitor field);
    attribute = (fun _ _ -> ());
    attributes = (fun _ _ -> ());
  }

let check ~max_lines ~max_switch_cases ~(source : Source.t) tree =
  let diagnostics = ref [] in
  let emit rule message location =
    diagnostics :=
      Diagnostic.
        {
          rule;
          message;
          filename = source.filename;
          range = Source_range.of_location ~source:source.text location;
          fixes = [];
          help = None;
          symbol = None;
        }
      :: !diagnostics
  in
  let lines = line_count source.text in
  if lines > max_lines then
    emit "max-lines"
      (Printf.sprintf
         "This file has %d physical lines; the configured maximum is %d." lines
         max_lines)
      file_start;
  let visitor = iterator ~source ~max_switch_cases emit in
  (match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items);
  Source_range.sort !diagnostics
