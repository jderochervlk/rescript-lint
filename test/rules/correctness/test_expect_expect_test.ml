let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ("missing assertion", assertions 1 "Vitest.test(\"works\", _ => save())");
    ( "expect assertion",
      assertions 0
        "Vitest.test(\"works\", t => \
         t->Vitest.expect(true)->Vitest.Expect.toBe(true))" );
    ( "assert assertion",
      assertions 0 "Vitest.test(\"works\", _ => Vitest.Assert.equal(1, 1))" );
    ( "assert module alias",
      assertions 0
        "open Vitest\n\
         module A = Assert\n\
         test(\"works\", _ => A.deepEqual(1, 1))" );
    ( "assertion count",
      assertions 0 "Vitest.test(\"works\", t => Vitest.assertions(t, 1))" );
    ( "has assertion",
      assertions 0 "Vitest.test(\"works\", t => t->Vitest.hasAssertion)" );
    ( "matcher direct API",
      assertions 0
        "Vitest.test(\"works\", _ => actual->Vitest.Expect.toBeDefined)" );
    ( "matcher module direct",
      assertions 0
        "Vitest.test(\"works\", _ => Vitest_Matchers.Float.toBeCloseTo(actual, \
         1.0, 2))" );
    ( "promise matcher",
      assertions 0
        "Vitest.testAsync(\"works\", async _ => {await \
         Vitest.Expect.Promise.toBe(actual, 1)})" );
    ( "unknown matcher not assertion",
      assertions 1 "Vitest.test(\"works\", _ => Vitest.Expect.unknown(actual))"
    );
    ( "unrelated expect not assertion",
      assertions 1 "Vitest.test(\"works\", _ => expect(true))" );
    ( "shadowed expect not assertion",
      assertions 1
        "open Vitest\n\
         let expect = value => value\n\
         test(\"works\", _ => expect(true))" );
    ( "named callback",
      assertions 0
        "let run = t => Vitest.expect(t, true)\nVitest.test(\"works\", run)" );
    ( "named callback without assertion",
      assertions 1 "let run = _ => save()\nVitest.test(\"works\", run)" );
    ( "unknown imported callback conservative",
      assertions 0 "Vitest.test(\"works\", Other.run)" );
    ( "local assertion helper",
      assertions 0
        "let assertValue = value => Vitest.Assert.assert_(value)\n\
         Vitest.test(\"works\", _ => assertValue(true))" );
    ( "uncalled helper not assertion",
      assertions 1
        "Vitest.test(\"works\", _ => {let helper = () => \
         Vitest.Assert.assert_(true); ()})" );
    ( "captured helper identity",
      assertions 0
        "open Vitest\n\
         let run = t => expect(t, true)\n\
         let expect = other\n\
         test(\"works\", run)" );
    ( "nested test does not satisfy parent",
      assertions 1
        "Vitest.test(\"outer\", _ => Vitest.test(\"inner\", t => \
         Vitest.expect(t, true)))" );
    ( "hook callback does not satisfy test",
      assertions 1
        "Vitest.test(\"outer\", _ => Vitest.beforeEach(() => \
         Vitest.Assert.assert_(true)))" );
    ( "todo missing assertion ignored",
      assertions 0 "Vitest.test(\"works\", ~todo=true, _ => ())" );
    ( "recursive helper terminates",
      assertions 1
        "let rec run = () => run()\nVitest.test(\"works\", _ => run())" );
    ( "explicit assertion FFI",
      assertions 0
        "@module(\"vitest\") external assertValue: bool => unit = \"assert\"\n\
         Vitest.test(\"works\", _ => assertValue(true))" );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
