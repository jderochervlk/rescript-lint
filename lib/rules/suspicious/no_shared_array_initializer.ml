let metadata =
  Rule_metadata.
    {
      id = "no-shared-array-initializer";
      category = Suspicious;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let shared_initializer report scope expression arguments =
  match arguments with
  | [ (_, length); (_, value) ]
    when Option.fold ~none:true
           ~some:(fun length -> length > 1)
           (integer length)
         && newly_mutable scope value ->
      report.emit "no-shared-array-initializer"
        "Every slot shares this mutable allocation; use Array.fromInitializer \
         to allocate each element separately."
        expression.Parsetree.pexp_loc
  | _ -> ()
