open React_semantic_support

let rule_ids =
  [
    React_no_unstable_nested_components.metadata.id;
    React_jsx_no_constructed_context_values.metadata.id;
    React_exhaustive_deps.metadata.id;
    React_no_new_prop_value.metadata.id;
  ]

let inspect_props ~source emit scope element =
  React_no_new_prop_value.inspect ~source emit element;
  React_jsx_no_constructed_context_values.inspect ~source emit scope element

let rec iterator ~source ~emit ~scope_at context =
  {
    Ast_iterator.default_iterator with
    expr =
      (fun _ expression -> visit ~source ~emit ~scope_at context expression);
    value_binding =
      (fun _ binding -> binding_visit ~source ~emit ~scope_at context binding);
    attribute = (fun _ _ -> ());
    attributes = (fun _ _ -> ());
  }

and visit ~source ~emit ~scope_at context expression =
  let scope = scope_at expression in
  let global =
    if context.in_function then context.global
    else Names.union context.stable (globals scope)
  in
  React_exhaustive_deps.inspect_dependencies ~source emit ~global scope
    expression;
  if context.render then
    Option.iter
      (inspect_props ~source emit scope)
      (Jsx_model.of_expression expression);
  let context =
    match expression.Parsetree.pexp_desc with
    | Pexp_fun _ -> { context with render = false; in_function = true; global }
    | _ -> context
  in
  Ast_iterator.default_iterator.expr
    (iterator ~source ~emit ~scope_at context)
    expression

and binding_visit ~source ~emit ~scope_at context
    (binding : Parsetree.value_binding) =
  if component binding.pvb_attributes then (
    React_no_unstable_nested_components.inspect ~source emit
      ~render:context.render binding;
    let global =
      Names.union context.stable (globals (scope_at binding.pvb_expr))
    in
    component_body ~source ~emit ~scope_at
      { context with render = true; in_function = true; global }
      binding.pvb_expr)
  else visit ~source ~emit ~scope_at context binding.pvb_expr

and component_body ~source ~emit ~scope_at context expression =
  match (Semantic_model.unwrap expression).Parsetree.pexp_desc with
  | Pexp_fun { arity; _ } ->
      parameters ~source ~emit ~scope_at context
        (Option.value ~default:1 arity)
        expression
  | Pexp_apply
      { funct; args = (Nolabel, callback) :: arguments; partial = false; _ }
    when List.mem
           (canonical (scope_at expression) funct)
           [ Some [ "React"; "memo" ]; Some [ "React"; "forwardRef" ] ] ->
      component_body ~source ~emit ~scope_at context callback;
      List.iter
        (fun (_, argument) ->
          visit ~source ~emit ~scope_at { context with render = false } argument)
        arguments
  | _ -> visit ~source ~emit ~scope_at context expression

and parameters ~source ~emit ~scope_at context remaining expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_fun { default; rhs; _ } when remaining > 0 ->
      Option.iter (visit ~source ~emit ~scope_at context) default;
      parameters ~source ~emit ~scope_at context (remaining - 1) rhs
  | _ -> visit ~source ~emit ~scope_at context expression

let check ?(context = Semantic_model.default_context) ~source tree =
  let scope = initial context in
  let scope_at = expressions tree scope in
  let stable = React_exhaustive_deps.stable_hook_values scope tree in
  let findings = ref [] in
  let emit finding = findings := finding :: !findings in
  let visitor =
    iterator ~source ~emit ~scope_at
      {
        render = false;
        in_function = false;
        global = Names.union stable (globals scope);
        stable;
      }
  in
  (match tree with
  | Parser.Implementation structure -> visitor.structure visitor structure
  | Interface signature -> visitor.signature visitor signature);
  Source_range.sort (List.rev !findings)
