let rule_ids =
  [
    "no-optional-some";
    "preferred-type-syntax";
    "no-identity-operation";
    "no-erasing-operation";
    "no-modulo-one";
  ]

let optional_some emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_apply { args; _ } ->
      List.iter
        (function
          | ( Asttypes.Optional label,
              ({
                 Parsetree.pexp_desc =
                   Pexp_construct ({ txt = Lident "Some"; _ }, Some _);
                 _;
               } as argument) )
            when Semantic_model.Names.find_opt "Some"
                   scope.Semantic_model.constructors
                 = Some (Semantic_model.Option Unknown) ->
              emit "no-optional-some"
                ("Pass ~" ^ label.txt
               ^ " directly instead of wrapping it in Some for an optional \
                  argument.")
                argument.pexp_loc
          | _ -> ())
        args
  | _ -> ()

let dictionary emit scope (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr (identifier, [ _ ])
    when Semantic_model.standard_type scope identifier.txt
         = Some [ "Dict"; "t" ] ->
      emit "preferred-type-syntax"
        "Prefer the builtin dict type to the standard Dict.t alias."
        identifier.loc
  | _ -> ()

let integer (expression : Parsetree.expression) =
  match (Semantic_model.unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_integer (value, None)) -> int_of_string_opt value
  | _ -> None

let identity name left right =
  match name with
  | "+" -> left = Some 0 || right = Some 0
  | "*" -> left = Some 1 || right = Some 1
  | "-" -> right = Some 0
  | "/" -> right = Some 1
  | _ -> false

let erasing name left right = name = "*" && (left = Some 0 || right = Some 0)

let operator ~source scope (funct : Parsetree.expression) =
  match funct.pexp_desc with
  | Pexp_ident ({ txt = Lident "mod"; _ } as identifier) ->
      Option.bind (Semantic_model.resolve scope identifier.txt) (fun value ->
          if value.api = Some [ "Stdlib"; "mod" ] then Some "mod" else None)
  | _ -> (
      match Expression_rules.operator ~source funct with
      | Some "%" -> Some "mod"
      | name -> name)

let arithmetic ~source emit scope (expression : Parsetree.expression) =
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
              expression.pexp_loc;
          if erasing name lhs rhs then
            emit "no-erasing-operation"
              "This integer operation always produces zero; preserve any \
               operand effects when simplifying."
              expression.pexp_loc;
          if name = "mod" && (rhs = Some 1 || rhs = Some (-1)) then
            emit "no-modulo-one"
              "Integer remainder by one or negative one always produces zero."
              expression.pexp_loc)
        (operator ~source scope funct)
  | _ -> ()

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
          optional_some emit scope expression;
          arithmetic ~source emit scope expression);
      core_type = dictionary emit;
    }
  in
  Semantic_walk.iter callbacks (Semantic_model.initial context) tree;
  Source_range.sort !findings
