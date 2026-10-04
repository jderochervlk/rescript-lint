open Rescript_linter

let scope = Semantic_model.initial Semantic_model.default_context

let ast_identifier name =
  Ast_helper.Exp.ident (Location.mknoloc (Longident.Lident name))

let ast_integer value = Ast_helper.Exp.constant (Pconst_integer (value, None))

let constrained expression =
  Ast_helper.Exp.constraint_ expression (Ast_helper.Typ.any ())

let semantic_checks =
  let open Semantic_rule_support in
  [
    ("regexp is compound", compound Semantic_model.Regexp);
    ("result is compound", compound (Result Int));
    ("result risk includes payload", risk (Result (Array Int)) = 6);
    ("reverse at-most comparison", invert "<=" = ">=");
    ( "strict length comparisons",
      empty_comparison "!==" (Some 0) && empty_comparison "<=" (Some 0) );
    ( "descending empty loop",
      empty_loop (ast_integer "0") (ast_integer "3") Asttypes.Downto );
    ( "descending nonempty loop",
      not (empty_loop (ast_integer "3") (ast_integer "0") Asttypes.Downto) );
    ( "dynamic loop bounds",
      not
        (empty_loop (ast_identifier "start") (ast_identifier "finish")
           Asttypes.Upto) );
    ( "partial list tail aliases",
      partial_alternative [ "List"; "tailExn" ] = Some "List.tail"
      && partial_alternative [ "List"; "tailOrThrow" ] = Some "List.tail" );
    ( "partial option aliases",
      partial_alternative [ "Option"; "getExn" ]
      = Some "an explicit Some/None match"
      && partial_alternative [ "Option"; "getOrThrow" ]
         = Some "an explicit Some/None match" );
    ( "partial result alias",
      partial_alternative [ "Result"; "getOrThrow" ]
      = Some "an explicit Ok/Error match" );
    ( "partial list head alias",
      partial_alternative [ "List"; "headOrThrow" ] = Some "List.head" );
  ]

let react_checks =
  let open React_dom_support in
  let expression = ast_identifier "index" in
  [
    ( "constrained expression path",
      expression_path (constrained expression) = Some [ "index" ] );
    ("literal has no expression path", expression_path (ast_integer "0") = None);
    ( "functor path is unresolved",
      path (Longident.Lapply (Lident "F", Lident "X")) = [] );
    ("constrained nonfunction", function_parts (constrained expression) = None);
    ( "wildcard parameter is unnamed",
      pattern_name (Ast_helper.Pat.any ()) = None );
    ( "aliased pattern shadows index",
      without_pattern (Some "index")
        (Ast_helper.Pat.alias (Ast_helper.Pat.any ()) (Location.mknoloc "index"))
      = None );
    ( "literal variant collection",
      static_collection
        (Ast_helper.Exp.array [ Ast_helper.Exp.variant "Value" None ]) );
  ]

let jsx_checks =
  let open Jsx_rule_support in
  [
    ( "list role compatibility",
      compatible_role "ul" "menu"
      && compatible_role "ol" "tree"
      && not (compatible_role "ul" "button") );
    ( "table role compatibility",
      compatible_role "table" "grid" && not (compatible_role "table" "button")
    );
    ( "cell role compatibility",
      compatible_role "td" "gridcell"
      && compatible_role "th" "gridcell"
      && not (compatible_role "td" "button") );
    ("unlisted tag role", not (compatible_role "div" "button"));
    ( "property conversion",
      react_aria_name "aria-label" = "ariaLabel"
      && react_aria_name "title" = "title" );
    ("uppercase alphabetic tag", ascii_alpha "ABC");
    ("alphabetic tag rejects number", not (ascii_alpha "12"));
    ("empty alphabetic tag", not (ascii_alpha ""));
    ("empty language accepted", valid_language "");
    ("three-letter language", valid_language "eng");
    ("nonalphabetic language", not (valid_language "123"));
    ("private invalid language", not (valid_language "x-?"));
    ("billing contact autocomplete", valid_autocomplete "billing home email");
    ("shipping phone autocomplete", valid_autocomplete "shipping mobile tel");
    ("work contact autocomplete", valid_autocomplete "work email");
    ("fax contact autocomplete", valid_autocomplete "fax tel");
    ("pager contact autocomplete", valid_autocomplete "pager tel");
    ("autocomplete on", valid_autocomplete "on");
  ]

let project_checks =
  [
    ( "functor reference remains unresolved",
      Project_rule_support.canonical_reference scope
        (Longident.Lapply (Lident "F", Lident "X"))
      = None );
  ]

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (semantic_checks @ react_checks @ jsx_checks @ project_checks))
