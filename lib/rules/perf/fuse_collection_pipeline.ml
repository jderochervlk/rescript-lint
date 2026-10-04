let metadata =
  Rule_metadata.
    {
      id = "fuse-collection-pipeline";
      category = Perf;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let fusion report scope expression name arguments =
  match (name, arguments) with
  | [ collection; "map" ], [ (_, inner); (_, outer_callback) ] -> (
      match call scope inner with
      | Some (funct, [ (_, _); (_, inner_callback) ])
        when api scope funct = Some [ collection; "map" ]
             && is_pure_callable scope inner_callback
             && is_pure_callable scope outer_callback ->
          report.emit "fuse-collection-pipeline"
            ("Compose these pure callbacks into one " ^ collection
           ^ ".map traversal.")
            expression.Parsetree.pexp_loc
      | _ -> ())
  | _ -> ()
