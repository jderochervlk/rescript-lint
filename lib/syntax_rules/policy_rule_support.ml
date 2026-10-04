type limits = {
  max_nesting : int;
  max_params : int;
  max_lines_per_function : int;
}

let default_limits =
  { max_nesting = 4; max_params = 5; max_lines_per_function = 50 }

type comment_context = Line | Block | Documentation

type warning_policy = {
  terms : string list;
  allowed_contexts : comment_context list;
}

let default_warning_terms = [ "TODO"; "FIXME"; "HACK" ]

let default_warning_policy =
  { terms = default_warning_terms; allowed_contexts = [] }

let warning_terms_config policy = policy.terms
let warning_contexts_config policy = policy.allowed_contexts
let term_initial = function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false

let term_character = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
  | _ -> false

let valid_term term =
  String.length term > 0
  && term_initial term.[0]
  && String.for_all term_character term

let duplicates compare values =
  List.length values <> List.length (List.sort_uniq compare values)

let warning_policy ~terms ~allowed_contexts =
  let terms = List.map String.uppercase_ascii terms in
  if terms = [] then Error "Warning-comment terms must not be empty."
  else if not (List.for_all valid_term terms) then
    Error
      "Warning-comment terms must be ASCII identifiers starting with a letter."
  else if duplicates String.compare terms then
    Error "Warning-comment terms must be unique ignoring ASCII case."
  else if duplicates compare allowed_contexts then
    Error "Allowed warning-comment contexts must be unique."
  else Ok { terms; allowed_contexts }

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

let control_flow (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ifthenelse _ | Pexp_match _ | Pexp_try _ | Pexp_while _ | Pexp_for _ ->
      true
  | _ -> false

let traverse visitor = function
  | Parser.Implementation tree -> visitor.Ast_iterator.structure visitor tree
  | Interface tree -> visitor.Ast_iterator.signature visitor tree
