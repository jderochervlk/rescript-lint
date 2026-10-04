open Rescript_linter

let checks_test_rules_test_support =
  let open Test_rules_test_support in
  [
    ("focused test", focused 1 "Vitest.test(\"works\", ~only=true, _ => ())");
    ( "focused describe",
      focused 1 "Vitest.describe(\"works\", ~only=true, () => ())" );
    ("focus false", focused 0 "Vitest.it(\"works\", ~only=false, _ => ())");
    ("dynamic focus", focused 0 "Vitest.test(\"works\", ~only=enabled, _ => ())");
    ( "optional focus",
      focused 1 "Vitest.test(\"works\", ~only=?Some(true), _ => ())" );
    ( "unrelated true option",
      focused 0 "Vitest.test(\"works\", ~concurrent=true, _ => ())" );
    ( "async runners",
      focused 2
        "Vitest.testAsync(\"works\", ~only=true, async _ => ()); \
         Vitest.itAsync(\"other\", ~only=true, async _ => ())" );
    ( "for runner",
      focused 1 "Vitest.For.test([1, 2], \"works\", ~only=true, (_, _) => ())"
    );
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
    ( "restore alias after unknown open",
      focused 1
        "module V = Vitest\n\
         module M = {open Other}\n\
         V.test(\"works\", ~only=true, _ => ())" );
    ( "constrained module exports",
      focused 1
        "module V: {let test: testType} = Vitest\n\
         V.test(\"works\", ~only=true, _ => ())" );
    ( "nested constrained export",
      focused 1
        "module V: {module For: {let test: testType}} = Vitest\n\
         V.For.test([1], \"works\", ~only=true, (_, _) => ())" );
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
    ( "local helper registration",
      focused 1
        "let tests = () => Vitest.test(\"works\", ~only=true, cb)\ntests()" );
    ( "interface ignored",
      check ~kind:Source.Interface "test/no-focused-tests" 0
        "@@example(Vitest.test(\"\", ~only=true, cb))\nlet x: int" );
    ( "dormant callback focus",
      focused 1 "let register = () => Vitest.test(\"works\", ~only=true, cb)" );
    ( "passed callback focus",
      focused 1 "Other.run(() => Vitest.test(\"works\", ~only=true, cb))" );
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

let () = Rule_test_runner.run checks_test_rules_test_support
