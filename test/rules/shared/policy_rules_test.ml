open Rescript_linter
open Policy_rules_test_support

let clean text = check [] text

let checks =
  [
    ("empty record return is meaningful", clean "let run = () => {}");
    ("typed intentional no-op", clean "let run = (): unit => ()");
    ("typed no-op block", clean "let run = (): unit => {}");
    ("meaningful body", clean "let run = () => Console.log(1)");
    ( "meaningful block ending in unit",
      clean "let run = () => {Console.log(1); ()}" );
    ("empty interface", check ~kind:Source.Interface [] "");
    ("interface declaration", check ~kind:Source.Interface [] "let value: int");
    ("effect-only implementation", clean "Console.log(1)");
    ("declaration", clean "let value = 1");
    ("non-warning documentation", clean "/** Completed work. */\nlet value = 1");
    ( "explicit doc annotation is not a comment",
      clean "@res.doc(\"TODO\") let value = 1" );
    ( "warning in empty file",
      check [ "no-empty-file"; "no-warning-comments" ] "// TODO\n" );
    ("strings are not comments", clean "let value = \"// TODO: FIXME HACK\"");
    ( "whole-word matching",
      clean "// TODOS NOTODO TODO_ HACKER FIXME2\nlet value = 1" );
    ("unicode adjacent text", clean "// TODO\195\169\nlet value = 1");
    ("non-warning comment", clean "// Completed work\nlet value = 1");
    ( "parameter boundary",
      check ~limits:params [] "let run = (first, second) => first + second" );
    ( "curried functions count independently",
      check ~limits:params []
        "let run = (first, second) => (third, fourth) => first + second + \
         third + fourth" );
    ( "unit argument excluded",
      check ~limits:{ params with max_params = 0 } [] "let run = () => 1" );
    ( "tuple destructuring is one parameter",
      check
        ~limits:{ params with max_params = 1 }
        [] "let run = ((first, second)) => first + second" );
    ("function line boundary", check ~limits:lines [] "let run = () => {\n1}");
    ( "top-level lines do not count",
      check ~limits:lines [] "let first = 1\nlet second = 2\nlet third = 3" );
    ( "control-flow boundary",
      check ~limits:nesting [] "if ready {run()} else {wait()}" );
    ( "else-if chains retain depth",
      check ~limits:nesting []
        "if ready {run()} else if active {wait()} else {stop()}" );
    ( "functions reset nesting",
      check ~limits:nesting []
        "if ready {let run = () => {if active {work()}}; run()}" );
    ( "module and record nesting excluded",
      check ~limits:nesting []
        "module Example = {let value = {field: if ready {1} else {2}}}" );
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
