let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "conditional test",
      conditional_test 1 "if enabled {Vitest.test(\"works\", cb)}" );
    ( "conditional suite",
      conditional_test 1 "if enabled {Vitest.describe(\"works\", cb)} else {()}"
    );
    ( "switch test",
      conditional_test 1
        "switch enabled {| true => Vitest.test(\"works\", cb) | false => ()}" );
    ( "loop test",
      conditional_test 1 "while enabled {Vitest.test(\"works\", cb)}" );
    ( "for test",
      conditional_test 1 "for i in 0 to 1 {Vitest.test(\"works\", cb)}" );
    ( "catch test",
      conditional_test 1
        "try {read()} catch {| _ => Vitest.test(\"works\", cb)}" );
    ( "conditional value outside callback",
      conditional_test 0 "Vitest.test(if enabled {\"a\"} else {\"b\"}, cb)" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
