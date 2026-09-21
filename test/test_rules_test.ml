open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "testing.res"; text; kind }

let lint ?kind ?max_nested_describe ?module_signatures text =
  let source = source ?kind text in
  Result.map
    (Test_rules.check ?max_nested_describe ?module_signatures ~source)
    (Parser.parse source)

let check ?kind ?max_nested_describe ?module_signatures rule expected text =
  match lint ?kind ?max_nested_describe ?module_signatures text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let found =
        List.filter
          (fun (value : Diagnostic.t) -> value.rule = rule)
          diagnostics
      in
      if List.length found = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d in %s" rule expected
             (List.length found) text)

let clean text =
  match lint text with
  | Error error -> Error (Lint_error.render error)
  | Ok [] -> Ok ()
  | Ok diagnostics ->
      Error (String.concat "\n" (List.map Diagnostic.render diagnostics))

let focused = check "test/no-focused-tests"
let disabled = check "test/no-disabled-tests"
let duplicate_title = check "test/no-identical-title"
let duplicate_hook = check "test/no-duplicate-hooks"
let conditional_test = check "test/no-conditional-test"
let conditional_expect = check "test/no-conditional-expect"
let hook_order = check "test/prefer-hooks-in-order"
let hooks_top = check "test/prefer-hooks-on-top"
let top_level = check "test/require-top-level-describe"
let title = check "test/valid-title"
let assertions = check "test/expect-expect"
let depth = check ~max_nested_describe:2 "test/max-nested-describe"

let exact_range =
  match lint "Vitest.test(\"works\", ~only=true, _ => ())" with
  | Ok diagnostics -> (
      match
        List.find_opt
          (fun (value : Diagnostic.t) -> value.rule = "test/no-focused-tests")
          diagnostics
      with
      | Some diagnostic
        when diagnostic.range.start.byte_offset = 27
             && diagnostic.range.finish.byte_offset = 31
             && diagnostic.filename = "testing.res"
             && diagnostic.fixes = [] ->
          Ok ()
      | _ -> Error "focused modifier range mismatch")
  | Error error -> Error (Lint_error.render error)

let project_open ?(name = "Prelude") signature expected text =
  match Parser.parse (source ~kind:Source.Interface signature) with
  | Ok (Parser.Interface signature) ->
      check
        ~module_signatures:[ (name, signature) ]
        "test/no-focused-tests" expected text
  | Ok (Implementation _) -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)

let checks =
  [
    ( "all registry IDs are distinct",
      if List.length (List.sort_uniq String.compare Test_rules.rule_ids) = 12
      then Ok ()
      else Error "rule IDs" );
    ("ordinary test name is unrelated", clean "test(\"\", ~only=true, _ => ())");
    ("unknown qualified API", clean "Other.test(\"\", ~only=true, _ => ())");
    ( "complete valid suite",
      clean
        "open Vitest\n\
         describe(\"user\", () => {beforeEach(reset); test(\"saves\", t => \
         t->expect(true)->Expect.toBe(true))})" );
    ("focused test", focused 1 "Vitest.test(\"works\", ~only=true, _ => ())");
    ( "focused describe",
      focused 1 "Vitest.describe(\"works\", ~only=true, () => ())" );
    ("focus false", focused 0 "Vitest.it(\"works\", ~only=false, _ => ())");
    ("dynamic focus", focused 0 "Vitest.test(\"works\", ~only=enabled, _ => ())");
    ( "optional focus",
      focused 1 "Vitest.test(\"works\", ~only=?Some(true), _ => ())" );
    ( "unrelated true option",
      focused 0 "Vitest.test(\"works\", ~concurrent=true, _ => ())" );
    ("disabled test", disabled 1 "Vitest.test(\"works\", ~skip=true, _ => ())");
    ( "todo option",
      disabled 1 "Vitest.describe(\"works\", ~todo=true, () => ())" );
    ("false skip", disabled 0 "Vitest.test(\"works\", ~skip=false, _ => ())");
    ( "todo module",
      disabled 3
        "Vitest.Todo.test(\"works\"); Vitest.Todo.it(\"other\"); \
         Vitest.Todo.describe(\"suite\")" );
    ( "async runners",
      focused 2
        "Vitest.testAsync(\"works\", ~only=true, async _ => ()); \
         Vitest.itAsync(\"other\", ~only=true, async _ => ())" );
    ( "for runner",
      focused 1 "Vitest.For.test([1, 2], \"works\", ~only=true, (_, _) => ())"
    );
    ("for title index", title 1 "Vitest.For.test([1], \"\", (_, _) => ())");
    ( "for describe async",
      title 1 "Vitest.For.describeAsync([1], \"\", async _ => ())" );
    ( "nonexistent each not recognized",
      clean "Vitest.Each.test([1], \"\", ~only=true, _ => ())" );
    ( "nonexistent todo async not recognized",
      clean "Vitest.Todo.testAsync(\"\")" );
    ("in-source API", title 1 "Vitest.InSource.test(\"\", _ => ())");
    ( "binding in-source alias",
      title 1 "Vitest_Bindings.InSource.describe(\"\", () => ())" );
    ( "nested binding in-source alias",
      title 1 "Vitest.Bindings.InSource.itAsync(\"\", async _ => ())" );
    ( "module alias",
      focused 1 "module V = Vitest\nV.test(\"works\", ~only=true, _ => ())" );
    ( "nested module alias",
      focused 1
        "module Helpers = {module V = Vitest}\n\
         Helpers.V.test(\"works\", ~only=true, _ => ())" );
    ( "value alias",
      focused 1 "let check = Vitest.test\ncheck(\"works\", ~only=true, _ => ())"
    );
    ( "constrained value alias",
      focused 1
        "let check = (Vitest.test: testType)\n\
         check(\"works\", ~only=true, _ => ())" );
    ( "open module",
      focused 1 "open Vitest\ntest(\"works\", ~only=true, _ => ())" );
    ( "local open",
      focused 1 "{open Vitest; test(\"works\", ~only=true, _ => ())}" );
    ( "include module",
      focused 1 "include Vitest\ntest(\"works\", ~only=true, _ => ())" );
    ( "module exports value alias",
      focused 1
        "module Helpers = {let run = Vitest.test}\n\
         Helpers.run(\"works\", ~only=true, _ => ())" );
    ( "module open is not reexport",
      clean
        "module Helpers = {open Vitest}\n\
         Helpers.test(\"\", ~only=true, _ => ())" );
    ( "module shadow",
      clean "module Vitest = Other\nVitest.test(\"\", ~only=true, _ => ())" );
    ( "local module shadow",
      clean "{module Vitest = Other; Vitest.test(\"\", ~only=true, _ => ())}" );
    ( "value shadow",
      clean "open Vitest\nlet test = custom\ntest(\"\", ~only=true, _ => ())" );
    ( "function parameter shadow",
      focused 0
        "let run = test => test(\"works\", ~only=true, _ => ())\nrun(custom)" );
    ( "destructured parameter shadow",
      focused 0
        "open Vitest\n\
         let run = (test, _) => test(\"works\", ~only=true, _ => ())\n\
         run((custom, 0))" );
    ( "local pattern shadow",
      focused 0
        "open Vitest\n\
         {let (test, _) = pair; test(\"works\", ~only=true, _ => ())}" );
    ( "alias pattern shadow",
      focused 0
        "open Vitest\n\
         {let custom as test = unknown; test(\"works\", ~only=true, _ => ())}"
    );
    ( "unknown open invalidates bindings",
      clean "open Vitest\nopen Other\ntest(\"\", ~only=true, _ => ())" );
    ( "unknown include invalidates bindings",
      clean "open Vitest\ninclude Other\ntest(\"\", ~only=true, _ => ())" );
    ( "unknown include invalidates exports",
      clean
        "module M = {let test = Vitest.test; include Other}\n\
         M.test(\"\", ~only=true, _ => ())" );
    ( "restore alias after unknown open",
      focused 1
        "module V = Vitest\n\
         module M = {open Other}\n\
         V.test(\"works\", ~only=true, _ => ())" );
    ( "recursive module shadow",
      clean
        "module rec Vitest: {} = {let x = Vitest.test(\"\", ~only=true, _ => \
         ())}" );
    ( "constrained module exports",
      focused 1
        "module V: {let test: testType} = Vitest\n\
         V.test(\"works\", ~only=true, _ => ())" );
    ( "hidden constrained export",
      clean "module V: {} = Vitest\nV.test(\"\", ~only=true, _ => ())" );
    ( "opaque module type",
      clean "module V: Hidden = Vitest\nV.test(\"\", ~only=true, _ => ())" );
    ( "nested constrained export",
      focused 1
        "module V: {module For: {let test: testType}} = Vitest\n\
         V.For.test([1], \"works\", ~only=true, (_, _) => ())" );
    ( "functor result opaque",
      clean "module V = Make(Vitest)\nV.test(\"\", ~only=true, _ => ())" );
    ( "explicit test FFI",
      focused 1
        "@module(\"vitest\") external run: (string, options, unit => unit) => \
         unit = \"test\"\n\
         run(\"works\", {only: true}, () => ())" );
    ( "explicit focused FFI",
      focused 1
        "@module(\"vitest\") @scope(\"test\") external run: (string, unit => \
         unit) => unit = \"only\"\n\
         run(\"works\", () => ())" );
    ( "explicit skipped FFI",
      disabled 1
        "@module(\"vitest\") @scope(\"describe\") external run: string => unit \
         = \"todo\"\n\
         run(\"works\")" );
    ( "unrelated FFI module",
      clean
        "@module(\"other\") external test: (string, options, unit => unit) => \
         unit = \"test\"\n\
         test(\"\", {only: true}, () => ())" );
    ( "unrelated FFI primitive",
      clean
        "@module(\"vitest\") external test: (string, options, unit => unit) => \
         unit = \"unknown\"\n\
         test(\"\", {only: true}, () => ())" );
    ( "unrelated FFI scope",
      clean
        "@module(\"vitest\") @scope(\"other\") external run: (string, unit => \
         unit) => unit = \"only\"\n\
         run(\"\", () => ())" );
    ( "external shadows opened API",
      clean
        "open Vitest\n\
         external test: (string, unit => unit) => unit = \"custom\"\n\
         test(\"\", () => ())" );
    ( "same sibling test title",
      duplicate_title 1
        "open Vitest\n\
         describe(\"suite\", () => {test(\"same\", cb); it(\"same\", cb)})" );
    ( "same sibling suite title",
      duplicate_title 1
        "Vitest.describe(\"same\", cb); Vitest.describe(\"same\", cb)" );
    ( "different sibling title",
      duplicate_title 0
        "Vitest.test(\"first\", cb); Vitest.test(\"second\", cb)" );
    ( "different suites permit same title",
      duplicate_title 0
        "open Vitest\n\
         describe(\"a\", () => test(\"same\", cb)); describe(\"b\", () => \
         test(\"same\", cb))" );
    ( "suite and test titles distinct categories",
      duplicate_title 0
        "Vitest.describe(\"same\", cb); Vitest.test(\"same\", cb)" );
    ( "dynamic title conservative",
      duplicate_title 0 "Vitest.test(name, cb); Vitest.test(name, cb)" );
    ( "duplicate before hook",
      duplicate_hook 1 "Vitest.beforeEach(reset); Vitest.beforeEach(reset)" );
    ( "async hook same identity",
      duplicate_hook 1 "Vitest.beforeEach(reset); Vitest.beforeEachAsync(reset)"
    );
    ( "hook scopes independent",
      duplicate_hook 0
        "open Vitest\n\
         beforeEach(reset); describe(\"nested\", () => beforeEach(reset))" );
    ( "hook alias identity",
      duplicate_hook 1
        "let setup = Vitest.beforeAll\nsetup(reset); Vitest.beforeAll(reset)" );
    ( "duplicate after hooks",
      duplicate_hook 2
        "Vitest.afterEach(clean); Vitest.afterEachAsync(clean); \
         Vitest.afterAll(clean); Vitest.afterAllAsync(clean)" );
    ( "hook order",
      hook_order 1 "Vitest.afterEach(clean); Vitest.beforeEach(setup)" );
    ( "complete hook order",
      hook_order 0
        "Vitest.beforeAll(setup); Vitest.beforeEach(setup); \
         Vitest.afterEach(clean); Vitest.afterAll(clean)" );
    ( "before all after each",
      hook_order 1 "Vitest.beforeEach(setup); Vitest.beforeAll(setup)" );
    ( "hooks after test",
      hooks_top 1 "Vitest.test(\"first\", cb); Vitest.beforeEach(setup)" );
    ( "hooks before test",
      hooks_top 0 "Vitest.beforeEach(setup); Vitest.test(\"first\", cb)" );
    ( "parent hook after nested suite",
      hooks_top 1 "Vitest.describe(\"nested\", cb); Vitest.afterAll(clean)" );
    ( "nested hook independent of parent tests",
      hooks_top 0
        "Vitest.test(\"first\", cb); Vitest.describe(\"nested\", () => \
         Vitest.beforeEach(setup))" );
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
    ("top-level test", top_level 1 "Vitest.test(\"works\", cb)");
    ( "test inside suite",
      top_level 0 "Vitest.describe(\"suite\", () => Vitest.test(\"works\", cb))"
    );
    ("empty test title", title 1 "Vitest.test(\"\", cb)");
    ("whitespace suite title", title 1 "Vitest.describe(\"  \", cb)");
    ("nonempty title", title 0 "Vitest.test(\"works\", cb)");
    ("dynamic title", title 0 "Vitest.test(title, cb)");
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
    ( "nested describes over limit",
      depth 1
        "open Vitest\n\
         describe(\"a\", () => describe(\"b\", () => describe(\"c\", cb)))" );
    ( "nested describes at limit",
      depth 0 "open Vitest\ndescribe(\"a\", () => describe(\"b\", cb))" );
    ( "named describe callback",
      top_level 0
        "let tests = () => Vitest.test(\"works\", cb)\n\
         Vitest.describe(\"suite\", tests)" );
    ( "local helper registration",
      focused 1
        "let tests = () => Vitest.test(\"works\", ~only=true, cb)\ntests()" );
    ( "recursive helper terminates",
      assertions 1
        "let rec run = () => run()\nVitest.test(\"works\", _ => run())" );
    ( "attribute payload ignored",
      clean "@example(Vitest.test(\"\", ~only=true, cb)) let x = 1" );
    ( "standalone attribute ignored",
      clean "@@example(Vitest.test(\"\", ~only=true, cb))\nlet x = 1" );
    ( "interface ignored",
      check ~kind:Source.Interface "test/no-focused-tests" 0
        "@@example(Vitest.test(\"\", ~only=true, cb))\nlet x: int" );
    ("runtime skip", disabled 1 "Vitest.test(\"works\", t => t->Vitest.skip)");
    ( "runtime skip alias",
      disabled 1 "let skip = Vitest.skip\nVitest.test(\"works\", t => skip(t))"
    );
    ( "runtime skipIf true",
      disabled 1 "Vitest.test(\"works\", t => t->Vitest.skipIf(true))" );
    ( "runtime skipIf false",
      disabled 0 "Vitest.test(\"works\", t => t->Vitest.skipIf(false))" );
    ( "runtime skipIf dynamic",
      disabled 0 "Vitest.test(\"works\", t => t->Vitest.skipIf(enabled))" );
    ( "runtime skip shadow",
      disabled 0
        "open Vitest\nlet skip = value => value\ntest(\"works\", t => skip(t))"
    );
    ( "swallowed assertion",
      conditional_expect 1
        "Vitest.test(\"works\", t => {try \
         {t->Vitest.expect(true)->Vitest.Expect.toBe(true)} catch {| _ => \
         ()}})" );
    ( "caught assertion",
      conditional_expect 1
        "Vitest.test(\"works\", t => {try {read()} catch {| _ => \
         Vitest.expect(t, true)}})" );
    ( "dormant callback focus",
      focused 1 "let register = () => Vitest.test(\"works\", ~only=true, cb)" );
    ( "dormant callback disabled",
      disabled 1 "let register = () => Vitest.test(\"works\", ~skip=true, cb)"
    );
    ( "dormant callback invalid title",
      title 1 "let register = () => Vitest.test(\"\", cb)" );
    ( "dormant suite ownership unknown",
      top_level 0 "let register = () => Vitest.test(\"works\", cb)" );
    ( "passed callback focus",
      focused 1 "Other.run(() => Vitest.test(\"works\", ~only=true, cb))" );
    ( "named callback titles not double counted",
      duplicate_title 0
        "let register = () => Vitest.test(\"works\", cb)\n\
         Vitest.describe(\"suite\", register)" );
    ( "explicit beforeAll FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"beforeAll\"\n\
         setup(cb); Vitest.beforeAll(cb)" );
    ( "explicit beforeEach FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"beforeEach\"\n\
         setup(cb); Vitest.beforeEach(cb)" );
    ( "explicit afterEach FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"afterEach\"\n\
         setup(cb); Vitest.afterEach(cb)" );
    ( "explicit afterAll FFI",
      duplicate_hook 1
        "@module(\"vitest\") external setup: (unit => unit) => unit = \
         \"afterAll\"\n\
         setup(cb); Vitest.afterAll(cb)" );
    ( "explicit assertion FFI",
      assertions 0
        "@module(\"vitest\") external assertValue: bool => unit = \"assert\"\n\
         Vitest.test(\"works\", _ => assertValue(true))" );
    ("exact range", exact_range);
    ( "known project open preserves adapter",
      project_open "type t = int\nlet helper: int" 1
        "open Prelude\nVitest.test(\"works\", ~only=true, cb)" );
    ( "known project open preserves imported binding",
      project_open "let helper: int" 1
        "open Vitest\nopen Prelude\ntest(\"works\", ~only=true, cb)" );
    ( "known project exported value shadows binding",
      project_open "let test: testType" 0
        "open Vitest\nopen Prelude\ntest(\"works\", ~only=true, cb)" );
    ( "known project module shadows adapter",
      project_open "module Vitest: {let test: testType}" 0
        "open Prelude\nVitest.test(\"works\", ~only=true, cb)" );
    ( "known project nested open",
      project_open "module Nested: {let helper: int}" 1
        "open Prelude.Nested\nVitest.test(\"works\", ~only=true, cb)" );
    ( "project module named Vitest is not the binding",
      project_open ~name:"Vitest" "let test: testType" 0
        "Vitest.test(\"works\", ~only=true, cb)" );
    ( "project signature reexports adapter alias",
      project_open "module V = Vitest" 1
        "Prelude.V.test(\"works\", ~only=true, cb)" );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
