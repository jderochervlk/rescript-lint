let metadata =
  Rule_metadata.
    { id = "prefer-pattern-check"; category = Perf; enabled_by_default = false }

open Semantic_model
open Semantic_rule_support

let pattern_check report scope expression operator left right =
  let check value pattern =
    match (infer scope value, (unwrap pattern).pexp_desc) with
    | (List _ | Variant true), Pexp_construct (_, Some _)
      when literal_pattern pattern ->
        report.emit "prefer-pattern-check"
          "Use a constructor pattern to test this fixed compound shape without \
           deep equality."
          expression.Parsetree.pexp_loc
    | _ -> ()
  in
  if List.mem operator [ "=="; "!=" ] then (
    check left right;
    check right left)
