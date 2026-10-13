open Semantic_model
open Semantic_rule_support

let rule_ids =
  [
    No_self_compare.metadata.id;
    No_unintended_shallow_equality.metadata.id;
    No_expensive_deep_equality.metadata.id;
    No_float_equality.metadata.id;
    Prefer_pattern_check.metadata.id;
    Prefer_empty_check.metadata.id;
    No_partial_function.metadata.id;
    No_dynamic_code.metadata.id;
    No_shared_array_initializer.metadata.id;
    No_floating_promise.metadata.id;
    Require_await.metadata.id;
    No_await_in_loop.metadata.id;
    Only_used_in_recursion.metadata.id;
    Eta_reduction.metadata.id;
    No_ignored_result.metadata.id;
    Fuse_collection_pipeline.metadata.id;
    No_accumulating_concat.metadata.id;
    No_top_level_side_effect.metadata.id;
    No_redundant_mutual_recursion.metadata.id;
    Prefer_standard_combinator.metadata.id;
  ]

let equality report context scope expression operator left right =
  No_self_compare.inspect report scope expression left right;
  No_unintended_shallow_equality.inspect report scope expression operator left
    right;
  No_expensive_deep_equality.inspect report context scope expression operator
    left right;
  No_float_equality.inspect report scope expression left right

let ignored report scope expression value =
  No_floating_promise.inspect report scope expression value;
  No_ignored_result.inspect report scope expression value

let application report scope expression funct arguments =
  No_partial_function.inspect report scope expression funct;
  (match api scope funct with
  | Some
      ([ "Stdlib"; "ignore" ] | [ "Promise"; "ignore" ] | [ "Result"; "ignore" ])
    -> (
      match arguments with
      | [ (_, value) ] -> ignored report scope expression value
      | _ -> ())
  | Some [ "Array"; "make" ] ->
      No_shared_array_initializer.shared_initializer report scope expression
        arguments
  | _ -> ());
  No_dynamic_code.application report scope expression funct;
  Option.iter
    (fun name ->
      Fuse_collection_pipeline.fusion report scope expression name arguments;
      No_accumulating_concat.accumulating report scope expression name arguments)
    (api scope funct)

let expression_rule report context scope expression =
  (match binary scope expression with
  | Some (operator, left, right) ->
      if List.mem operator [ "=="; "!="; "==="; "!==" ] then
        equality report context scope expression operator left right;
      Prefer_empty_check.length_check report scope expression operator left
        right;
      Prefer_pattern_check.pattern_check report scope expression operator left
        right
  | None -> ());
  (match call scope expression with
  | Some (funct, arguments) ->
      application report scope expression funct arguments
  | None -> ());
  No_dynamic_code.inspect report expression;
  Require_await.function_rule report scope expression;
  No_await_in_loop.loop_rule report scope expression

let binding_rule report scope flag bindings =
  Semantic_recursion.check ~emit:report.emit ~boundary:report.boundary scope
    flag bindings;
  List.iter
    (fun (binding : Parsetree.value_binding) ->
      match binding.pvb_pat.ppat_desc with
      | Ppat_any -> ignored report scope binding.pvb_expr binding.pvb_expr
      | _ -> ())
    bindings

let check ?(context = default_context) ~(source : Source.t) tree =
  let diagnostics = ref [] and boundaries = ref [] in
  let diagnostic rule message location =
    Diagnostic.
      {
        filename = source.filename;
        rule;
        message;
        help = None;
        symbol = None;
        fixes = [];
        range = Source_range.of_location ~source:source.text location;
      }
  in
  let emit rule message location =
    diagnostics := diagnostic rule message location :: !diagnostics
  in
  let boundary rule message location =
    if List.mem rule context.enabled then
      boundaries :=
        diagnostic rule ("Analysis boundary: " ^ message) location
        :: !boundaries
  in
  let report = { emit; boundary } in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression = expression_rule report context;
      bindings = binding_rule report;
      initialization = No_top_level_side_effect.top_level report context;
    }
  in
  Semantic_walk.iter callbacks (Semantic_runtime.initial_scope context) tree;
  match Source_range.sort !boundaries with
  | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
  | [] -> Ok (Source_range.sort !diagnostics)
