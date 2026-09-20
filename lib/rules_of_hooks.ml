type hook = Ordinary | Use
type owner = Other | Component | Custom_hook
type restriction = Conditional | Loop | Handler | Default_argument

type context =
  | Outside
  | Inside of { async : bool; restrictions : restriction list }

let is_hook_name name =
  String.length name > 3
  && String.starts_with ~prefix:"use" name
  && match name.[3] with 'A' .. 'Z' | '0' .. '9' -> true | _ -> false

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) | Pexp_newtype (_, inner) -> unwrap inner
  | _ -> expression

let identifier expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident identifier -> Some identifier
  | _ -> None

let expression_path expression =
  Option.bind (identifier expression) (fun identifier -> path identifier.txt)

let classify = function
  | [ "use" ] | [ "React"; "use" ] -> Some Use
  | names -> (
      match List.rev names with
      | name :: _ when is_hook_name name -> Some Ordinary
      | _ -> None)

let restrict restriction = function
  | Outside -> Outside
  | Inside state ->
      Inside { state with restrictions = restriction :: state.restrictions }

let restriction_message = function
  | Conditional -> "Do not call hooks conditionally."
  | Loop -> "Do not call hooks in loops."
  | Handler -> "Do not call hooks in try/catch or exception-handling switches."
  | Default_argument ->
      "Do not call hooks in default arguments. Move the call into the function \
       body."

let applies hook = function
  | Conditional | Loop -> hook = Ordinary
  | Handler | Default_argument -> true

let violation hook = function
  | Outside ->
      Some
        "Call hooks only at the top level of a React component or custom hook."
  | Inside { async = true; _ } -> Some "Do not call hooks in async functions."
  | Inside { restrictions; _ } ->
      Option.map restriction_message (List.find_opt (applies hook) restrictions)

let inspect ~emit context expression =
  Option.iter
    (fun (identifier : Longident.t Location.loc) ->
      let hook = Option.bind (path identifier.txt) classify in
      let message = Option.bind hook (fun hook -> violation hook context) in
      Option.iter (fun message -> emit identifier.loc message) message)
    (identifier expression)

let is_component attributes =
  List.exists
    (fun ((name : string Location.loc), _) ->
      List.mem name.txt
        [ "react.component"; "jsx.component"; "react.componentWithProps" ])
    attributes

let rec pattern_name (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name -> Some name.txt
  | Ppat_constraint (inner, _) -> pattern_name inner
  | _ -> None

let binding_owner (binding : Parsetree.value_binding) =
  if is_component binding.pvb_attributes then Component
  else if
    Option.fold ~none:false ~some:is_hook_name (pattern_name binding.pvb_pat)
  then Custom_hook
  else Other

let rec catches_exception (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_exception _ -> true
  | Ppat_or (left, right) -> catches_exception left || catches_exception right
  | Ppat_constraint (inner, _) | Ppat_alias (inner, _) ->
      catches_exception inner
  | _ -> false

let is_react_wrapper expression =
  match expression_path expression with
  | Some [ "React"; ("memo" | "forwardRef") ] -> true
  | _ -> false

let function_context owner async =
  match owner with
  | Other -> Outside
  | Component | Custom_hook -> Inside { async; restrictions = [] }

let rec iterator ~emit context : Ast_iterator.iterator =
  let default = Ast_iterator.default_iterator in
  {
    default with
    expr = (fun _ expression -> visit ~emit context expression);
    value_binding =
      (fun _ binding ->
        bound_expression ~emit context (binding_owner binding) binding.pvb_expr);
    module_expr =
      (fun _ expression ->
        let outer = iterator ~emit Outside in
        default.module_expr outer expression);
    attributes = (fun _ _ -> ());
  }

and visit ~emit context (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_fun _ -> bound_expression ~emit context Other expression
  | Pexp_apply { funct; args; _ } -> application ~emit context funct args
  | Pexp_match (value, cases) -> switch ~emit context value cases
  | Pexp_try (body, cases) ->
      let protected = restrict Handler context in
      visit ~emit protected body;
      List.iter (visit_case ~emit protected) cases
  | _ -> control_flow ~emit context expression

and control_flow ~emit context (expression : Parsetree.expression) =
  let walk = visit ~emit context in
  let restricted restriction = visit ~emit (restrict restriction context) in
  match expression.pexp_desc with
  | Pexp_ifthenelse (condition, yes, no) ->
      walk condition;
      restricted Conditional yes;
      Option.iter (restricted Conditional) no
  | Pexp_while (condition, body) ->
      restricted Loop condition;
      restricted Loop body
  | Pexp_for (_, first, last, _, body) ->
      walk first;
      walk last;
      restricted Loop body
  | _ ->
      let visitor = iterator ~emit context in
      Ast_iterator.default_iterator.expr visitor expression

and application ~emit context funct args =
  let walk = visit ~emit context in
  match (expression_path funct, args) with
  | Some [ ("&&" | "||") ], [ (_, left); (_, right) ] ->
      walk left;
      visit ~emit (restrict Conditional context) right
  | Some [ "->" ], [ (_, value); (_, target) ] ->
      walk value;
      inspect ~emit context target;
      walk target
  | _ ->
      inspect ~emit context funct;
      walk funct;
      List.iter (fun (_, argument) -> walk argument) args

and switch ~emit context value cases =
  let protected =
    if List.exists (fun case -> catches_exception case.Parsetree.pc_lhs) cases
    then restrict Handler context
    else context
  in
  visit ~emit protected value;
  List.iter (visit_case ~emit (restrict Conditional protected)) cases

and visit_case ~emit context (case : Parsetree.case) =
  Option.iter (visit ~emit context) case.pc_guard;
  visit ~emit context case.pc_rhs

and bound_expression ~emit context owner expression =
  let expression = unwrap expression in
  match expression.pexp_desc with
  | Pexp_fun { arity; async; _ } ->
      parameters ~emit
        (function_context owner async)
        (Option.value ~default:1 arity)
        expression
  | Pexp_apply { funct; args = (_, render) :: rest; _ }
    when owner = Component && is_react_wrapper funct ->
      bound_expression ~emit context Component render;
      List.iter (fun (_, argument) -> visit ~emit context argument) rest
  | _ -> visit ~emit context expression

and parameters ~emit context remaining (expression : Parsetree.expression) =
  (* The parser nests parameter nodes; only the outer node starts a new function. *)
  match expression.pexp_desc with
  | Pexp_fun { default; rhs; _ } when remaining > 0 ->
      Option.iter (visit ~emit (restrict Default_argument context)) default;
      parameters ~emit context (remaining - 1) rhs
  | _ -> visit ~emit context expression

let check ~(source : Source.t) tree =
  (* Mutation is confined to the compiler's unit-returning iterator boundary. *)
  let diagnostics = ref [] in
  let emit location message =
    let diagnostic =
      Diagnostic.
        {
          filename = source.filename;
          rule = "react/rules-of-hooks";
          message;
          range = Source_range.of_location ~source:source.text location;
        }
    in
    diagnostics := diagnostic :: !diagnostics
  in
  let visitor = iterator ~emit Outside in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  Source_range.sort (List.rev !diagnostics)
