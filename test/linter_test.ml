open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "example.res"; text; kind }

let count ?kind expected text =
  match Linter.lint_source (source ?kind text) with
  | Ok diagnostics when List.length diagnostics = expected -> Ok ()
  | Ok diagnostics ->
      Error
        (Printf.sprintf "Expected %d findings, got %d: %s" expected
           (List.length diagnostics) text)
  | Error error -> Error (Lint_error.render error)

let expect name passed = (name, if passed then Ok () else Error name)

let invalid kind text =
  match Linter.lint_source (source ~kind text) with
  | Error (Lint_error.Parse_errors (first, _)) ->
      first.rule = "syntax"
      && first.filename = "example.res"
      && first.range.start.line >= 1
      && first.message <> ""
  | _ -> false

let range_check =
  match Linter.lint_source (source "// comment\n  Console.log(42)\n") with
  | Ok [ diagnostic ] ->
      diagnostic
      = Diagnostic.
          {
            filename = "example.res";
            rule = "no-console";
            message = "Do not use Console.log.";
            range =
              {
                start = { line = 2; column = 3; byte_offset = 13 };
                finish = { line = 2; column = 14; byte_offset = 24 };
              };
          }
  | _ -> false

let utf8_check =
  let text = "let text = \"\195\169\"; Console.log(text)" in
  match Linter.lint_source (source text) with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.column = 18
      && diagnostic.range.start.byte_offset = 17
  | _ -> false

let ordered_check =
  match
    Linter.lint_source (source "Console.log(Console.warn(1))\nConsole.error(2)")
  with
  | Ok diagnostics ->
      List.map (fun (d : Diagnostic.t) -> d.range.start.byte_offset) diagnostics
      = [ 0; 12; 29 ]
  | _ -> false

let unicode_range prefix suffix =
  let text = prefix ^ "Console.log" ^ suffix in
  match Linter.lint_source (source text) with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.byte_offset = String.length prefix
      && diagnostic.range.finish.byte_offset = String.length prefix + 11
  | _ -> false

let multiple_errors =
  match Linter.lint_source (source "let = 1\nlet = 2") with
  | Error (Lint_error.Parse_errors (first, second :: _)) ->
      first.range.start.line = 1
      && second.range.start.line = 2
      && String.length
           (Lint_error.render (Lint_error.Parse_errors (first, [ second ])))
         > String.length first.message
  | _ -> false

let functor_path =
  let identifier =
    Longident.Ldot (Lapply (Lident "F", Lident "Console"), "log")
  in
  let expression = Ast_helper.Exp.ident (Location.mknoloc identifier) in
  let tree = Parser.Implementation [ Ast_helper.Str.eval expression ] in
  Banned_api.check ~rules:[ No_console.rule ] ~source:(source "") tree = []

let newline_boundary =
  let position =
    Lexing.
      { pos_fname = "example.res"; pos_lnum = 1; pos_bol = 0; pos_cnum = 4 }
  in
  let range =
    Source_range.of_positions ~source:"\195\169\nrest" position position
  in
  range.start.byte_offset = 2 && range.finish.column = 3

let checks =
  [
    ("clean", count 0 "let answer = 42");
    ("empty", count 0 "");
    ( "comments and strings",
      count 0
        "// Console.log(1)\n/* Js.log(2) */\nlet text = \"Console.warn(3)\"" );
    ("raw JavaScript stays opaque", count 0 "%%raw(`console.log(42)`)");
    ("pipe", count 1 "42->Console.log");
    ("value alias", count 1 "let log = Console.log\nlog(1)");
    ("callback", count 1 "items->Array.forEach(Console.log)");
    ("nested function", count 1 "let f = () => {Console.log(1)}");
    ("template interpolation", count 1 "let text = `${Console.log(1)}`");
    ( "unrelated symbols",
      count 0 "let log = x => x\nlet _ = Other.Console.log(log(1))" );
    ( "unknown members",
      count 0 "Console.unknown()\nJs.warn(1)\nJs.Console.debug(1)" );
    ( "local shadow",
      count 0 "module Console = {let log = x => x}\nConsole.log(1)" );
    ( "nested shadow stays nested",
      count 1
        "module Nested = {module Console = Other\n\
         let x = Console.log(1)}\n\
         Console.log(2)" );
    ( "shadow not retroactive",
      count 1 "Console.log(1)\nmodule Console = Other\nConsole.log(2)" );
    ( "module initializer scope",
      count 1 "module Console = {let x = Console.log(1)}" );
    ( "block-local shadow",
      count 1
        "let f = () => {module Console = Other\nConsole.log(1)}\nConsole.log(2)"
    );
    ( "functor shadow",
      count 0
        "module F = (Console: {let log: int => unit}) => {let x = \
         Console.log(1)}" );
    ( "recursive shadow",
      count 0
        "module rec Console: {let log: int => unit} = {let log = x => \
         Console.log(x)}" );
    ( "interface",
      count ~kind:Source.Interface 0
        "let answer: int\nmodule Console: {let log: int => unit}" );
    ("annotations", count 0 "@deprecated(\"Console.log\")\nlet answer = 42");
    expect "implementation syntax failure"
      (invalid Source.Implementation "let =");
    expect "interface syntax failure" (invalid Source.Interface "let x:");
    expect "exclusive source range" range_check;
    expect "UTF-8 byte columns" utf8_check;
    expect "astral Unicode"
      (unicode_range "let text = \"\240\159\152\128\"; " "(text)");
    expect "Unicode on previous line"
      (unicode_range "let text = \"\195\169\"\n" "(text)");
    expect "Unicode before EOF"
      (unicode_range "let text = \"\195\169\"; let log = " "");
    expect "Unicode before newline"
      (unicode_range "let text = \"\195\169\"; let log = " "\n");
    expect "multiple parse errors retained" multiple_errors;
    expect "source order" ordered_check;
    expect "functor application is not a standard module path" functor_path;
    expect "position conversion stays on its source line" newline_boundary;
  ]

let api_checks =
  List.concat_map
    (fun (prefix, members) ->
      List.map
        (fun member ->
          let name = prefix ^ "." ^ member in
          (name, count 1 ("let reference = " ^ name)))
        members)
    [
      ( "Console",
        [
          "log";
          "log6";
          "logMany";
          "debug";
          "debug6";
          "warn";
          "warn6";
          "errorMany";
          "info5";
          "assert_";
          "assertMany";
          "clear";
          "count";
          "countReset";
          "dir";
          "dirxml";
          "group";
          "groupCollapsed";
          "groupEnd";
          "table";
          "time";
          "timeEnd";
          "timeLog";
          "trace";
        ] );
      ("Stdlib.Console", [ "log"; "warn" ]);
      ("Stdlib_Console", [ "log" ]);
      ( "Js.Console",
        [ "log"; "log4"; "warnMany"; "timeStart"; "timeEnd"; "table" ] );
      ("Js_console", [ "log"; "info4"; "errorMany"; "trace" ]);
      ("Js", [ "log"; "log2"; "log3"; "log4"; "logMany" ]);
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ api_checks)
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
