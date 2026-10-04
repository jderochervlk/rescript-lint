open Rescript_linter

let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ("raw code", yes "no-dynamic-code" "let value = %raw(\"eval(input)\")");
    ( "ordinary external",
      no "no-dynamic-code"
        "@val external evaluate: string => int = \"evaluate\"" );
    ( "resolved external eval",
      yes "no-dynamic-code"
        "@val external evaluate: string => int = \"eval\"\n\
         let run = code => evaluate(code)" );
    ( "scoped eval is not global eval",
      no "no-dynamic-code"
        "@val @scope(\"Safe\") external evaluate: string => int = \"eval\"\n\
         let run = code => evaluate(code)" );
    ( "standalone attribute excluded",
      no "no-dynamic-code" "@@example(%raw(\"eval(input)\"))" );
    ( "global Function constructor",
      yes "no-dynamic-code"
        "@new external compile: string => (unit => int) = \"Function\"\n\
         let run = code => compile(code)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support

let raw_check name =
  let findings = ref [] in
  let report =
    Semantic_rule_support.
      {
        emit =
          (fun rule message location ->
            findings := (rule, message, location) :: !findings);
        boundary = (fun _ _ _ -> ());
      }
  in
  let expression = Ast_helper.Exp.extension (Location.mknoloc name, PStr []) in
  No_dynamic_code.inspect report expression;
  match !findings with
  | [ (rule, message, location) ] ->
      rule = "no-dynamic-code" && message <> ""
      && location = expression.pexp_loc
  | _ -> false

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (List.map
          (fun name -> (name ^ " raw extension", raw_check name))
          [ "raw"; "bs.raw"; "res.raw" ]))
