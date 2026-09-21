type limits = {
  max_nesting : int;
  max_params : int;
  max_lines_per_function : int;
}

let default_limits =
  { max_nesting = 4; max_params = 5; max_lines_per_function = 50 }

let unit_pattern (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_construct ({ txt = Lident "()"; _ }, None) -> true
  | _ -> false

let unit_type (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr ({ txt = Lident "unit"; _ }, []) -> true
  | _ -> false

let rec empty_body (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_construct ({ txt = Lident "()"; _ }, None) -> true
  | Pexp_constraint (body, typ) -> (not (unit_type typ)) && empty_body body
  | _ -> false

let rec function_body remaining (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_fun { rhs; _ } when remaining > 0 -> function_body (remaining - 1) rhs
  | _ -> expression

let parameter_count arity pattern =
  if arity = 1 && unit_pattern pattern then 0 else arity

let report_limit ~emit rule noun maximum actual location =
  if actual > maximum then
    emit rule
      (Printf.sprintf "This %s has %d; the configured maximum is %d." noun
         actual maximum)
      location

let inspect_function ~emit limits arity pattern expression =
  let body = function_body arity expression in
  let location = expression.Parsetree.pexp_loc in
  if empty_body body then
    emit "no-empty-function"
      "This function has an empty body; annotate an intentional no-op with a \
       unit return type."
      location;
  report_limit ~emit "max-params" "function's parameter list" limits.max_params
    (parameter_count arity pattern)
    location;
  let lines = location.loc_end.pos_lnum - location.loc_start.pos_lnum + 1 in
  report_limit ~emit "max-lines-per-function" "function's physical line span"
    limits.max_lines_per_function lines location

let control_flow (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse _ | Pexp_match _ | Pexp_try _ | Pexp_while _ | Pexp_for _ ->
      true
  | _ -> false

let report_nesting ~emit limits depth expression =
  if depth = limits.max_nesting + 1 then
    emit "max-nesting"
      (Printf.sprintf
         "Control-flow nesting exceeds the configured maximum of %d."
         limits.max_nesting)
      expression.Parsetree.pexp_loc

let rec iterator ~emit limits depth =
  {
    Ast_iterator.default_iterator with
    expr = (fun _ expression -> visit ~emit limits depth expression);
    attribute = (fun _ _ -> ());
  }

and visit ~emit limits depth (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_fun { arity; lhs; _ } ->
      let arity = Option.value ~default:1 arity in
      inspect_function ~emit limits arity lhs expression;
      visit_parameters ~emit limits arity expression
  | Pexp_ifthenelse (condition, body, otherwise) ->
      visit_if ~emit limits depth expression condition body otherwise
  | _ ->
      let depth = if control_flow expression then depth + 1 else depth in
      if control_flow expression then
        report_nesting ~emit limits depth expression;
      Ast_iterator.default_iterator.expr
        (iterator ~emit limits depth)
        expression

and visit_parameters ~emit limits remaining (expression : Parsetree.expression)
    =
  match expression.pexp_desc with
  | Pexp_fun { default; rhs; _ } when remaining > 0 ->
      Option.iter (visit ~emit limits 0) default;
      visit_parameters ~emit limits (remaining - 1) rhs
  | _ -> visit ~emit limits 0 expression

and visit_if ~emit limits depth expression condition body otherwise =
  report_nesting ~emit limits (depth + 1) expression;
  visit ~emit limits (depth + 1) condition;
  visit ~emit limits (depth + 1) body;
  Option.iter
    (fun (otherwise : Parsetree.expression) ->
      let depth =
        match otherwise.pexp_desc with
        | Pexp_ifthenelse _ -> depth
        | _ -> depth + 1
      in
      visit ~emit limits depth otherwise)
    otherwise

let word_character = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
  | character -> Char.code character >= 128

let warning_terms text =
  let words =
    text |> String.uppercase_ascii
    |> String.map (fun character ->
        if word_character character then character else ' ')
    |> String.split_on_char ' '
  in
  List.filter (fun term -> List.mem term words) [ "TODO"; "FIXME"; "HACK" ]

let inspect_warning ~emit text location =
  match warning_terms text with
  | [] -> ()
  | terms ->
      emit "no-warning-comments"
        ("This comment contains a warning term: " ^ String.concat ", " terms
       ^ ".")
        location

let inspect_comment ~emit comment =
  let location = Res_comment.loc comment in
  let location =
    if Res_comment.is_single_line_comment comment then
      let start = location.loc_start in
      { location with loc_start = { start with pos_cnum = start.pos_cnum - 2 } }
    else location
  in
  inspect_warning ~emit (Res_comment.txt comment) location

let documentation_source ~(source : Source.t) location =
  let range = Source_range.of_location ~source:source.text location in
  let start = range.start.byte_offset in
  start >= 0
  && start + 3 <= String.length source.text
  && String.sub source.text start 3 = "/**"

let inspect_attribute ~source ~emit = function
  | ( { Location.txt = "res.doc"; loc },
      Parsetree.PStr
        [
          {
            pstr_desc =
              Pstr_eval
                ({ pexp_desc = Pexp_constant (Pconst_string (text, _)); _ }, _);
            _;
          };
        ] )
    when documentation_source ~source loc ->
      inspect_warning ~emit text loc
  | _ -> ()

let traverse visitor = function
  | Parser.Implementation tree -> visitor.Ast_iterator.structure visitor tree
  | Interface tree -> visitor.Ast_iterator.signature visitor tree

let inspect_documentation ~source ~emit tree =
  traverse
    {
      Ast_iterator.default_iterator with
      attribute = (fun _ attribute -> inspect_attribute ~source ~emit attribute);
    }
    tree

let meaningful_item (item : Parsetree.structure_item) =
  match item.pstr_desc with Pstr_attribute _ -> false | _ -> true

let inspect_empty_file ~emit = function
  | Parser.Implementation items when not (List.exists meaningful_item items) ->
      let position =
        { Lexing.dummy_pos with pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
      in
      emit "no-empty-file" "This implementation file contains no declarations."
        { Location.loc_start = position; loc_end = position; loc_ghost = false }
  | _ -> ()

let check ?(limits = default_limits) ~(source : Source.t)
    (document : Parser.document) =
  (* Mutation stays inside the compiler's unit-returning iterator boundary. *)
  let diagnostics = ref [] in
  let emit rule message location =
    diagnostics :=
      Diagnostic.
        {
          filename = source.filename;
          rule;
          message;
          range = Source_range.of_location ~source:source.text location;
          fixes = [];
        }
      :: !diagnostics
  in
  inspect_empty_file ~emit document.tree;
  List.iter (inspect_comment ~emit) document.comments;
  inspect_documentation ~source ~emit document.tree;
  let visitor = iterator ~emit limits 0 in
  traverse visitor document.tree;
  Source_range.sort (List.rev !diagnostics)
