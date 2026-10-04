let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "promise ignored",
      yes "no-floating-promise" "let save = () => Promise.resolve(1)->ignore" );
    ("promise wildcard", yes "no-floating-promise" "let _ = Promise.resolve(1)");
    ( "promise stored",
      no "no-floating-promise" "let promise = Promise.resolve(1)" );
    ( "promise through local block",
      yes "no-floating-promise"
        "let save = () => {let promise = Promise.resolve(1); promise}\n\
         let run = () => save()->ignore" );
    ( "unknown discarded promise boundary",
      boundary "no-floating-promise" "let run = () => unknown()->ignore" );
    ( "shadowed ignore",
      no "no-floating-promise"
        "let ignore = promise => promise\n\
         let result = ignore(Promise.resolve(1))" );
    ( "imported promise",
      imported_check "no-floating-promise"
        "let save = () => Api.compute(1)->ignore" );
    ( "promise type alias",
      yes "no-floating-promise"
        "let run = (pending: Promise.t<int>) => ignore(pending)" );
    ( "promise-specific ignore",
      yes "no-floating-promise"
        "let run = () => Promise.ignore(Promise.resolve(1))" );
    ( "computed function callee",
      no "no-floating-promise" "let value = make()(1, 2)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
