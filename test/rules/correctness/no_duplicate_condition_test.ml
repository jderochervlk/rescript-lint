let checks_control_flow_rules_test_support =
  let open Control_flow_rules_test_support in
  [
    ( "duplicate else-if condition",
      duplicate "if status == #ready {a} else if status == #ready {b} else {c}"
    );
    ( "three duplicate conditions are reported once each",
      check
        [ "no-duplicate-condition"; "no-duplicate-condition" ]
        "if ready {a} else if ready {b} else if ready {c} else {d}" );
    ( "stable constructor conditions",
      duplicate
        "if value == Some(ready) {a} else if value == Some(ready) {b} else {c}"
    );
    ( "stable tuple conditions",
      duplicate
        "if value == (ready, #active) {a} else if value == (ready, #active) \
         {b} else {c}" );
    ( "duplicate switch guards on the same pattern",
      duplicate
        "switch value {| Some(x) if ready => x | Some(x) if ready => 0 | _ => \
         1}" );
    ( "stable intervening tests preserve duplicate conditions",
      duplicate "if ready {a} else if enabled {b} else if ready {c} else {d}" );
    ( "intervening different patterns preserve stable duplicate guards",
      duplicate
        "switch value {| Some(x) if ready => x | None if enabled => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
    ( "three duplicate switch guards report later occurrences only",
      check
        [ "no-duplicate-condition"; "no-duplicate-condition" ]
        "switch value {| Some(x) if ready => x | Some(x) if ready => 0 | \
         Some(x) if ready => 1 | _ => 2}" );
  ]

let () = Rule_test_runner.run checks_control_flow_rules_test_support
