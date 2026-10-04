let metadata =
  Rule_metadata.
    {
      id = "no-erasing-operation";
      category = Correctness;
      enabled_by_default = false;
    }

open Idiom_rule_support

let erasing name left right = name = "*" && (left = Some 0 || right = Some 0)

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
          if erasing name lhs rhs then
            emit "no-erasing-operation"
              "This integer operation always produces zero; preserve any \
               operand effects when simplifying."
              expression.pexp_loc)
        (operator ~source scope funct)
  | _ -> ()
