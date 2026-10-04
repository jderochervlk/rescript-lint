let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ("async without await", yes "require-await" "let load = async () => 42");
    ( "async with await",
      no "require-await" "let load = async () => await Promise.resolve(42)" );
    ( "known promise adapter",
      no "require-await" "let load = async () => Promise.resolve(42)" );
    ( "unknown adapter boundary",
      boundary "require-await" "let load = async () => fetch()" );
    ( "binding async adapter annotation",
      no "require-await" "@lint.promiseAdapter\nlet run = async () => 42" );
    ( "await in nested function only",
      check "require-await" 1
        "let outer = async () => {let inner = async () => await \
         Promise.resolve(1); 1}" );
    ( "unreachable conditional await",
      yes "require-await"
        "let run = async () => if false {await Promise.resolve(1)} else {1}" );
    ( "reachable true conditional await",
      no "require-await"
        "let run = async () => if true {await Promise.resolve(1)} else {1}" );
    ( "unreachable while await",
      yes "require-await"
        "let run = async () => {while false {await Promise.resolve()}; 1}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
