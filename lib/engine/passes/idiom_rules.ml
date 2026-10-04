let rule_ids =
  [
    No_optional_some.metadata.id;
    Preferred_type_syntax.metadata.id;
    No_identity_operation.metadata.id;
    No_erasing_operation.metadata.id;
    No_modulo_one.metadata.id;
  ]

let check ~context ~(source : Source.t) tree =
  let findings = ref [] in
  let emit rule message location =
    findings :=
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
      :: !findings
  in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression =
        (fun scope expression ->
          No_optional_some.optional_some emit scope expression;
          No_identity_operation.inspect ~source emit scope expression;
          No_erasing_operation.inspect ~source emit scope expression;
          No_modulo_one.inspect ~source emit scope expression);
      core_type = Preferred_type_syntax.dictionary emit;
    }
  in
  Semantic_walk.iter callbacks (Semantic_model.initial context) tree;
  Source_range.sort !findings
