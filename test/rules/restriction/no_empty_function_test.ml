let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ("empty function", empty "let run = () => ()");
    ( "multiple parameters yield one empty finding",
      empty "let run = (a, b) => ()" );
    ("unit-valued block", empty "let run = () => {()}");
    ("non-unit annotation does not exempt", empty "let run = (): other => ()");
    ("empty async function", empty "let run = async () => ()");
    ("returned empty function", empty "let run = () => () => ()");
    ( "function location",
      check_range "no-empty-function" 1 11 1 19 "let run = () => ()" );
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
