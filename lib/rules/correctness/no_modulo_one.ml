let metadata =
  Rule_metadata.
    { id = "no-modulo-one"; category = Correctness; enabled_by_default = false }

open Idiom_rule_support

let inspect ~source emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_apply
      {
        funct;
        args = [ (Nolabel, left); (Nolabel, right) ];
        partial = false;
        _;
      }
    when Semantic_model.infer scope left = Int
         && Semantic_model.infer scope right = Int ->
      Option.iter
        (fun name ->
          let lhs, rhs = (integer left, integer right) in
          if name = "mod" && (rhs = Some 1 || rhs = Some (-1)) then
            emit "no-modulo-one"
              "Integer remainder by one or negative one always produces zero."
              expression.pexp_loc)
        (operator ~source scope funct)
  | _ -> ()
