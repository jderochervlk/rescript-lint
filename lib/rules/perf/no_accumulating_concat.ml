let metadata =
  Rule_metadata.
    {
      id = "no-accumulating-concat";
      category = Perf;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let accumulating report scope expression name arguments =
  match (name, arguments) with
  | [ ("Array" | "List"); "reduce" ], [ _; _; (_, callback) ] -> (
      let parameters, body = function_parts callback in
      match parameters with
      | (_, accumulator) :: _ -> (
          let nested =
            List.fold_left
              (fun scope (_, pattern) -> bind_pattern scope Unknown pattern)
              scope parameters
          in
          match (binary nested body, pattern_name accumulator) with
          | Some ("++", left, _), Some name -> (
              match
                (identifier nested left, Names.find_opt name nested.values)
              with
              | Some left, Some accumulator
                when left.identity = accumulator.identity ->
                  report.emit "no-accumulating-concat"
                    "This fold repeatedly copies the growing string; collect \
                     the parts and join once."
                    expression.Parsetree.pexp_loc
              | _ -> ())
          | _ -> ())
      | [] -> ())
  | _ -> ()
