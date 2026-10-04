let rule_ids =
  [
    No_obj_external.metadata.id;
    No_mutable_record_field.metadata.id;
    No_record_mutation.metadata.id;
    No_while.metadata.id;
    No_for.metadata.id;
    No_empty_loop.metadata.id;
    No_negated_condition.metadata.id;
    No_nested_ternary.metadata.id;
    Prefer_if.metadata.id;
    No_single_case_switch.metadata.id;
    No_unnecessary_template.metadata.id;
    Max_lines.metadata.id;
    Max_switch_cases.metadata.id;
  ]

let iterator ~source ~max_switch_cases emit =
  let default = Ast_iterator.default_iterator in
  {
    default with
    expr =
      (fun visitor expression ->
        No_while.inspect emit expression;
        No_for.inspect emit expression;
        No_empty_loop.inspect emit expression;
        No_negated_condition.inspect ~source emit expression;
        No_nested_ternary.inspect emit expression;
        Prefer_if.inspect emit expression;
        No_single_case_switch.inspect emit expression;
        Max_switch_cases.inspect ~maximum:max_switch_cases emit expression;
        No_record_mutation.inspect emit expression;
        No_unnecessary_template.inspect ~source emit expression;
        default.expr visitor expression);
    value_description =
      (fun visitor value ->
        No_obj_external.inspect_external emit value;
        default.value_description visitor value);
    label_declaration =
      (fun visitor field ->
        No_mutable_record_field.inspect emit field;
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
  Max_lines.inspect ~maximum:max_lines emit source;
  let visitor = iterator ~source ~max_switch_cases emit in
  (match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items);
  Source_range.sort !diagnostics
