open Rescript_linter
open Test_rules_test_support

let clean text =
  match lint text with
  | Error error -> Error (Lint_error.render error)
  | Ok [] -> Ok ()
  | Ok diagnostics ->
      Error (String.concat "\n" (List.map Diagnostic.render diagnostics))

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
    ( "nonexistent each not recognized",
      clean "Vitest.Each.test([1], \"\", ~only=true, _ => ())" );
    ( "nonexistent todo async not recognized",
      clean "Vitest.Todo.testAsync(\"\")" );
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
    ( "unknown open invalidates bindings",
      clean "open Vitest\nopen Other\ntest(\"\", ~only=true, _ => ())" );
    ( "unknown include invalidates bindings",
      clean "open Vitest\ninclude Other\ntest(\"\", ~only=true, _ => ())" );
    ( "unknown include invalidates exports",
      clean
        "module M = {let test = Vitest.test; include Other}\n\
         M.test(\"\", ~only=true, _ => ())" );
    ( "recursive module shadow",
      clean
        "module rec Vitest: {} = {let x = Vitest.test(\"\", ~only=true, _ => \
         ())}" );
    ( "hidden constrained export",
      clean "module V: {} = Vitest\nV.test(\"\", ~only=true, _ => ())" );
    ( "opaque module type",
      clean "module V: Hidden = Vitest\nV.test(\"\", ~only=true, _ => ())" );
    ( "functor result opaque",
      clean "module V = Make(Vitest)\nV.test(\"\", ~only=true, _ => ())" );
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
    ( "attribute payload ignored",
      clean "@example(Vitest.test(\"\", ~only=true, cb)) let x = 1" );
    ( "standalone attribute ignored",
      clean "@@example(Vitest.test(\"\", ~only=true, cb))\nlet x = 1" );
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
