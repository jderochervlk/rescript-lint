let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ("disabled test", disabled 1 "Vitest.test(\"works\", ~skip=true, _ => ())");
    ( "todo option",
      disabled 1 "Vitest.describe(\"works\", ~todo=true, () => ())" );
    ("false skip", disabled 0 "Vitest.test(\"works\", ~skip=false, _ => ())");
    ( "todo module",
      disabled 3
        "Vitest.Todo.test(\"works\"); Vitest.Todo.it(\"other\"); \
         Vitest.Todo.describe(\"suite\")" );
    ( "explicit skipped FFI",
      disabled 1
        "@module(\"vitest\") @scope(\"describe\") external run: string => unit \
         = \"todo\"\n\
         run(\"works\")" );
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
    ( "dormant callback disabled",
      disabled 1 "let register = () => Vitest.test(\"works\", ~skip=true, cb)"
    );
  ]

let () = Rule_test_runner.run checks_test_rules_test_support
