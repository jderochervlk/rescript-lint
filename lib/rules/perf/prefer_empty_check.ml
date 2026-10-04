let metadata =
  Rule_metadata.
    { id = "prefer-empty-check"; category = Perf; enabled_by_default = false }

open Semantic_model
open Semantic_rule_support

let length_check report scope expression operator left right =
  let inspect operator length number =
    match call scope length with
    | Some (funct, [ _ ]) when empty_comparison operator (integer number) -> (
        match api scope funct with
        | Some [ "List"; "length" ] ->
            report.emit "prefer-empty-check"
              "Match list{} instead of traversing the list to compute its \
               length."
              expression.Parsetree.pexp_loc
        | Some [ (("Array" | "String") as name); "length" ] ->
            report.emit "prefer-empty-check"
              ("Use " ^ name ^ ".isEmpty for an explicit emptiness check.")
              expression.pexp_loc
        | _ -> ())
    | _ -> ()
  in
  inspect operator left right;
  inspect (invert operator) right left
