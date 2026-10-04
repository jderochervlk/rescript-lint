let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "unknown discarded result boundary",
      boundary "no-ignored-result" "let run = () => unknown()->ignore" );
    ( "result ignored",
      yes "no-ignored-result" "let validate = () => Ok(1)->ignore" );
    ("result wildcard", yes "no-ignored-result" "let _ = Error(\"invalid\")");
    ("result stored", no "no-ignored-result" "let result = Ok(1)");
    ( "imported result",
      imported_check "no-ignored-result"
        "let validate = () => Api.validate(\"input\")->ignore" );
    ( "result type alias",
      yes "no-ignored-result"
        "let run = (result: Result.t<int, string>) => ignore(result)" );
    ("safe primitive ignore", no "no-ignored-result" "let run = () => ignore(1)");
    ( "result-specific ignore",
      yes "no-ignored-result" "let run = () => Result.ignore(Ok(1))" );
    ( "option array get result",
      no "no-ignored-result" "let run = () => ignore(Array.get([1], 0))" );
    ( "list head result",
      no "no-ignored-result" "let run = () => ignore(List.head(list{1}))" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
