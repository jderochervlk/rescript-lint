open Policy_rule_support

let rule_ids =
  [
    No_empty_function.metadata.id;
    No_empty_file.metadata.id;
    No_warning_comments.metadata.id;
    Max_nesting.metadata.id;
    Max_params.metadata.id;
    Max_lines_per_function.metadata.id;
  ]

type limits = Policy_rule_support.limits = {
  max_nesting : int;
  max_params : int;
  max_lines_per_function : int;
}

type comment_context = Policy_rule_support.comment_context =
  | Line
  | Block
  | Documentation

type warning_policy = Policy_rule_support.warning_policy

let default_limits = Policy_rule_support.default_limits
let default_warning_terms = Policy_rule_support.default_warning_terms
let default_warning_policy = Policy_rule_support.default_warning_policy
let warning_terms_config = Policy_rule_support.warning_terms_config
let warning_contexts_config = Policy_rule_support.warning_contexts_config
let warning_policy = Policy_rule_support.warning_policy

let inspect_function ~emit (limits : limits) arity pattern expression =
  No_empty_function.inspect ~emit arity expression;
  Max_params.inspect ~emit limits.max_params arity pattern expression;
  Max_lines_per_function.inspect ~emit limits.max_lines_per_function expression

let report_nesting = Max_nesting.report_nesting

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

let check ?(limits = default_limits) ?(warning_policy = default_warning_policy)
    ~(source : Source.t) (document : Parser.document) =
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
          help = None;
          symbol = None;
          fixes = [];
        }
      :: !diagnostics
  in
  No_empty_file.inspect_empty_file ~emit document.tree;
  List.iter
    (No_warning_comments.inspect_comment ~emit warning_policy)
    document.comments;
  No_warning_comments.inspect_documentation ~source ~emit warning_policy
    document.tree;
  let visitor = iterator ~emit limits 0 in
  traverse visitor document.tree;
  Source_range.sort (List.rev !diagnostics)
