type truth = Always_true | Always_false

type scalar =
  | Bool of bool
  | Int of int64
  | Float of float
  | String of Literal_string.t
  | Char of int

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) | Pexp_newtype (_, inner) -> unwrap inner
  | _ -> expression

let expression_path expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident identifier -> path identifier.txt
  | _ -> None

let boolean_literal expression =
  match (unwrap expression).pexp_desc with
  | Pexp_construct ({ txt = Lident "true"; _ }, None) -> Some true
  | Pexp_construct ({ txt = Lident "false"; _ }, None) -> Some false
  | _ -> None

let encoded_char value =
  if String.length value = 0 then None
  else
    let decoded = String.get_utf_8_uchar value 0 in
    if
      Uchar.utf_decode_is_valid decoded
      && Uchar.utf_decode_length decoded = String.length value
    then Some (Char (Uchar.to_int (Uchar.utf_decode_uchar decoded)))
    else None

let integer_literal value =
  Option.bind (Int64.of_string_opt value) (fun value ->
      if value >= -2147483648L && value <= 2147483647L then Some (Int value)
      else None)

let string_value value =
  Option.map (fun value -> String value) (Literal_string.decode value)

let scalar expression =
  match (unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_integer (value, None)) -> integer_literal value
  | Pexp_constant (Pconst_float (value, None)) ->
      Option.map (fun value -> Float value) (Float.of_string_opt value)
  | Pexp_constant (Pconst_string (value, Some "INTERNAL_RES_CHAR_CONTENTS")) ->
      encoded_char value
  | Pexp_constant (Pconst_string (value, None)) -> string_value value
  | Pexp_constant (Pconst_char value) -> Some (Char value)
  | _ -> Option.map (fun value -> Bool value) (boolean_literal expression)

let binary expression =
  match (unwrap expression).pexp_desc with
  | Pexp_apply
      {
        funct;
        args = [ (Nolabel, left); (Nolabel, right) ];
        partial = false;
        _;
      } ->
      Option.map (fun names -> (names, left, right)) (expression_path funct)
  | _ -> None

let scalar_equal left right =
  match (left, right) with
  | Bool left, Bool right -> Some (Bool.equal left right)
  | Int left, Int right -> Some (Int64.equal left right)
  | Float left, Float right -> Some (Float.equal left right)
  | String left, String right -> Some (Literal_string.equal left right)
  | Char left, Char right -> Some (Int.equal left right)
  | _ -> None

let scalar_compare left right =
  match (left, right) with
  | Int left, Int right -> Some (Int64.compare left right)
  | Float left, Float right -> Some (Float.compare left right)
  | String left, String right -> Some (Literal_string.compare left right)
  | Char left, Char right -> Some (Int.compare left right)
  | _ -> None

let comparison operator left right =
  match (scalar left, scalar right) with
  | Some left, Some right -> (
      match operator with
      | "==" | "===" -> scalar_equal left right
      | "!=" | "!==" -> Option.map not (scalar_equal left right)
      | "<" -> Option.map (fun result -> result < 0) (scalar_compare left right)
      | "<=" ->
          Option.map (fun result -> result <= 0) (scalar_compare left right)
      | ">" -> Option.map (fun result -> result > 0) (scalar_compare left right)
      | ">=" ->
          Option.map (fun result -> result >= 0) (scalar_compare left right)
      | _ -> None)
  | _ -> None

let truth_of_bool value = if value then Always_true else Always_false
let bool_of_truth = function Always_true -> true | Always_false -> false

let rec truth expression =
  match boolean_literal expression with
  | Some value -> Some (truth_of_bool value)
  | None -> (
      match binary expression with
      | Some ([ "&&" ], left, right) -> and_truth left right
      | Some ([ "||" ], left, right) -> or_truth left right
      | Some ([ operator ], left, right) ->
          Option.map truth_of_bool (comparison operator left right)
      | _ -> None)

and and_truth left right =
  match (truth left, truth right) with
  | Some Always_false, _ | _, Some Always_false -> Some Always_false
  | Some Always_true, Some Always_true -> Some Always_true
  | _ -> None

and or_truth left right =
  match (truth left, truth right) with
  | Some Always_true, _ | _, Some Always_true -> Some Always_true
  | Some Always_false, Some Always_false -> Some Always_false
  | _ -> None

let pure_operators =
  [ "&&"; "||"; "=="; "!="; "==="; "!=="; "<"; "<="; ">"; ">=" ]

let rec stable expression =
  let expression = unwrap expression in
  match expression.pexp_desc with
  | Pexp_ident _ | Pexp_constant _ -> true
  | Pexp_construct (_, value) | Pexp_variant (_, value) ->
      Option.fold ~none:true ~some:stable value
  | Pexp_tuple values -> List.for_all stable values
  | Pexp_apply { funct; args; partial = false; _ } -> (
      match expression_path funct with
      | Some [ operator ] when List.mem operator pure_operators ->
          List.for_all (fun (_, argument) -> stable argument) args
      | _ -> false)
  | _ -> false

let locationless_mapper =
  { Ast_mapper.default_mapper with location = (fun _ _ -> Location.none) }

let normalized expression =
  locationless_mapper.expr locationless_mapper expression

let normalized_pattern pattern =
  locationless_mapper.pat locationless_mapper pattern

let equivalent left right =
  stable left && stable right && normalized left = normalized right

let emit ~source diagnostics rule message (expression : Parsetree.expression) =
  diagnostics :=
    Diagnostic.
      {
        filename = source.Source.filename;
        rule;
        message;
        fixes = [];
        range = Source_range.of_location ~source:source.text expression.pexp_loc;
      }
    :: !diagnostics

let report_constant ~source diagnostics expression =
  Option.iter
    (fun result ->
      let value = string_of_bool (bool_of_truth result) in
      emit ~source diagnostics "no-constant-condition"
        ("This condition is always " ^ value ^ ".")
        expression)
    (truth expression)

let report_constant_binary ~source diagnostics expression =
  match (binary expression, truth expression) with
  | Some _, Some result ->
      let value = string_of_bool (bool_of_truth result) in
      emit ~source diagnostics "no-constant-binary-expression"
        ("This binary expression always evaluates to " ^ value ^ ".")
        expression
  | _ -> ()

let report_duplicates ~source diagnostics expressions =
  let rec loop previous = function
    | [] -> ()
    | expression :: rest ->
        if List.exists (equivalent expression) previous then
          emit ~source diagnostics "no-duplicate-condition"
            "This condition duplicates an earlier condition in the same chain."
            expression;
        let previous =
          if stable expression then expression :: previous else []
        in
        loop previous rest
  in
  loop [] expressions

let report_identical ~source diagnostics expressions =
  let rec loop = function
    | previous :: (current :: _ as rest) ->
        if normalized previous = normalized current then
          emit ~source diagnostics "no-identical-branches"
            "This branch is identical to the preceding branch." current;
        loop rest
    | _ -> ()
  in
  loop expressions

let if_chain expression =
  let rec loop branches expression =
    match (unwrap expression).pexp_desc with
    | Pexp_ifthenelse (condition, body, Some otherwise) ->
        loop ((condition, body) :: branches) otherwise
    | Pexp_ifthenelse (condition, body, None) ->
        (List.rev ((condition, body) :: branches), None)
    | _ -> (List.rev branches, Some expression)
  in
  loop [] expression

let inspect_if ~source diagnostics expression condition =
  let branches, otherwise = if_chain expression in
  report_constant ~source diagnostics condition;
  report_duplicates ~source diagnostics (List.map fst branches);
  report_identical ~source diagnostics
    (List.map snd branches @ Option.to_list otherwise)

let pattern_bindings pattern =
  let names = ref [] in
  let unpacks_module = ref false in
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      pat =
        (fun iterator pattern ->
          (match pattern.Parsetree.ppat_desc with
          | Ppat_var name | Ppat_alias (_, name) -> names := name.txt :: !names
          | Ppat_unpack _ -> unpacks_module := true
          | _ -> ());
          default.pat iterator pattern);
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  visitor.pat visitor pattern;
  (!names, !unpacks_module)

let references names expression =
  let found = ref false in
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      expr =
        (fun iterator expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_ident { txt = Lident name; _ } ->
              if List.mem name names then found := true
          | _ -> ());
          default.expr iterator expression);
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  visitor.expr visitor expression;
  !found

let same_pattern (left : Parsetree.case) (right : Parsetree.case) =
  normalized_pattern left.pc_lhs = normalized_pattern right.pc_lhs

let comparable_bodies (left : Parsetree.case) (right : Parsetree.case) =
  let left_bindings, left_unpack = pattern_bindings left.pc_lhs in
  let right_bindings, right_unpack = pattern_bindings right.pc_lhs in
  let bindings = left_bindings @ right_bindings in
  same_pattern left right
  || (not (left_unpack || right_unpack))
     && not (references bindings left.pc_rhs || references bindings right.pc_rhs)

let report_switch_guards ~source diagnostics cases =
  let rec loop previous = function
    | [] -> ()
    | (case : Parsetree.case) :: rest ->
        let comparable = List.filter (same_pattern case) previous in
        let guards =
          List.filter_map (fun case -> case.Parsetree.pc_guard) comparable
          |> List.rev
        in
        let guards = guards @ Option.to_list case.pc_guard in
        report_duplicates ~source diagnostics guards;
        let previous =
          match case.pc_guard with
          | Some guard when stable guard -> case :: previous
          | _ -> []
        in
        loop previous rest
  in
  loop [] cases

let report_switch_bodies ~source diagnostics cases =
  let rec loop = function
    | previous :: (current :: _ as rest) ->
        if comparable_bodies previous current then
          report_identical ~source diagnostics
            [ previous.pc_rhs; current.pc_rhs ];
        loop rest
    | _ -> ()
  in
  loop cases

let inspect_switch ~source diagnostics cases =
  let guards = List.filter_map (fun case -> case.Parsetree.pc_guard) cases in
  List.iter (report_constant ~source diagnostics) guards;
  report_switch_guards ~source diagnostics cases;
  report_switch_bodies ~source diagnostics cases

let inspect ~source diagnostics (expression : Parsetree.expression) =
  report_constant_binary ~source diagnostics expression;
  match expression.pexp_desc with
  | Pexp_ifthenelse (condition, _, _) ->
      inspect_if ~source diagnostics expression condition
  | Pexp_match (_, cases) -> inspect_switch ~source diagnostics cases
  | Pexp_while (condition, _) -> report_constant ~source diagnostics condition
  | _ -> ()

let same_finding (left : Diagnostic.t) (right : Diagnostic.t) =
  left.rule = right.rule
  && left.range.start.byte_offset = right.range.start.byte_offset
  && left.range.finish.byte_offset = right.range.finish.byte_offset

let deduplicate diagnostics =
  List.fold_left
    (fun findings diagnostic ->
      if List.exists (same_finding diagnostic) findings then findings
      else diagnostic :: findings)
    [] diagnostics
  |> List.rev

let check ~(source : Source.t) tree =
  let diagnostics = ref [] in
  let visitor =
    let default = Ast_iterator.default_iterator in
    {
      default with
      expr =
        (fun iterator expression ->
          inspect ~source diagnostics expression;
          default.expr iterator expression);
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation structure -> visitor.structure visitor structure
  | Interface signature -> visitor.signature visitor signature);
  !diagnostics |> List.rev |> Source_range.sort |> deduplicate
