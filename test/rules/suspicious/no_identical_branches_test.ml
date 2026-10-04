let checks_control_flow_rules_test_support =
  let open Control_flow_rules_test_support in
  [
    ("identical if branches", identical "if ready {render()} else {render()}");
    ( "identical adjacent else-if branches",
      identical "if ready {render()} else if blocked {render()} else {wait()}"
    );
    ( "comments do not distinguish branches",
      identical "if ready {/* first */ render()} else {/* second */ render()}"
    );
    ( "identical switch branches",
      identical "switch value {| Some(_) => render() | None => render()}" );
    ( "identical switch bodies independent of bindings",
      identical "switch value {| Some(x) => render() | None => render()}" );
    ( "same-pattern identical switch bodies",
      identical "switch value {| Some(x) if ready => x | Some(x) => x | _ => 0}"
    );
    ( "same module-unpack pattern preserves identical body detection",
      identical
        "switch value {| module(M) if ready => M.value | module(M) => M.value}"
    );
  ]

let () = Rule_test_runner.run checks_control_flow_rules_test_support
