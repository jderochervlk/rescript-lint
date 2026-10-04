let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ( "conditional expect",
      conditional_expect 1
        "Vitest.test(\"works\", t => {if enabled \
         {t->Vitest.expect(1)->Vitest.Expect.toBe(1)}})" );
    ( "direct matcher conditional",
      conditional_expect 1
        "Vitest.test(\"works\", t => {let actual = Vitest.expect(t, 1); if \
         enabled {Vitest.Expect.toBe(actual, 1)}})" );
    ( "ordinary expect unrecognized",
      conditional_expect 0
        "Vitest.test(\"works\", t => {if enabled {expect(t, 1)}})" );
    ( "conditional expected value is fine",
      conditional_expect 0
        "Vitest.test(\"works\", t => {let value = if enabled {1} else {2}; \
         t->Vitest.expect(value)->Vitest.Expect.toBe(value)})" );
    ( "expect outside test",
      conditional_expect 0 "if enabled {Vitest.expect(t, 1)}" );
    ( "short circuit expect",
      conditional_expect 1
        "Vitest.test(\"works\", t => {enabled && Vitest.expect(t, true)})" );
    ( "or short circuit expect",
      conditional_expect 1
        "Vitest.test(\"works\", t => {enabled || Vitest.expect(t, true)})" );
    ( "switch assertion",
      conditional_expect 1
        "Vitest.test(\"works\", t => switch x {| Some(_) => Vitest.expect(t, \
         true) | None => ()})" );
    ( "test callback resets registration condition",
      conditional_expect 0
        "if enabled {Vitest.test(\"works\", t => Vitest.expect(t, true))}" );
    ( "hook assertion is not test conditional",
      conditional_expect 0
        "Vitest.beforeEach(() => {if enabled {Vitest.Assert.assert_(true)}})" );
    ( "swallowed assertion",
      conditional_expect 1
        "Vitest.test(\"works\", t => {try \
         {t->Vitest.expect(true)->Vitest.Expect.toBe(true)} catch {| _ => \
         ()}})" );
    ( "caught assertion",
      conditional_expect 1
        "Vitest.test(\"works\", t => {try {read()} catch {| _ => \
         Vitest.expect(t, true)}})" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
