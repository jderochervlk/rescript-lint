open Expression_rule_support

let rule_ids =
  [
    Simplify_boolean_expression.metadata.id;
    No_useless_concat.metadata.id;
    Approx_constant.metadata.id;
  ]

let operator = Expression_rule_support.operator

let inspect ~source expression =
  List.filter_map Fun.id
    [
      Simplify_boolean_expression.inspect ~source expression;
      No_useless_concat.inspect ~source expression;
      Approx_constant.inspect expression;
    ]
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
