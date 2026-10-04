let metadata =
  Rule_metadata.
    {
      id = "no-identity-operation";
      category = Correctness;
      enabled_by_default = false;
    }

open Idiom_rule_support

let identity name left right =
  match name with
  | "+" -> left = Some 0 || right = Some 0
  | "*" -> left = Some 1 || right = Some 1
  | "-" -> right = Some 0
  | "/" -> right = Some 1
  | _ -> false

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
          if identity name lhs rhs then
            emit "no-identity-operation"
              "This integer operation leaves its operand unchanged."
              expression.pexp_loc)
        (operator ~source scope funct)
  | _ -> ()
