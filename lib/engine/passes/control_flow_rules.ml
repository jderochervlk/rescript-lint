let inspect ~source diagnostics expression =
  No_constant_binary_expression.inspect ~source diagnostics expression;
  No_constant_condition.inspect ~source diagnostics expression;
  No_duplicate_condition.inspect ~source diagnostics expression;
  No_identical_branches.inspect ~source diagnostics expression

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
