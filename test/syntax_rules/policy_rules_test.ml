open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "policy.res"; text; kind }

let diagnostics ?kind ?limits text =
  let source = source ?kind text in
  Result.map (Policy_rules.check ?limits ~source) (Parser.parse_document source)

let check ?kind ?limits expected text =
  match diagnostics ?kind ?limits text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let actual =
        List.map (fun (item : Diagnostic.t) -> item.rule) diagnostics
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " actual)
             text)

let clean text = check [] text
let empty text = check [ "no-empty-function" ] text
let warning text = check [ "no-warning-comments" ] text
let nesting = { Policy_rules.default_limits with max_nesting = 1 }
let params = { Policy_rules.default_limits with max_params = 2 }
let lines = { Policy_rules.default_limits with max_lines_per_function = 2 }

let check_range rule start_line start_column finish_line finish_column text =
  match diagnostics text with
  | Ok [ item ]
    when item.rule = rule
         && item.range.start.line = start_line
         && item.range.start.column = start_column
         && item.range.finish.line = finish_line
         && item.range.finish.column = finish_column ->
      Ok ()
  | Ok _ -> Error "Unexpected diagnostic range"
  | Error error -> Error (Lint_error.render error)

let checks =
  [
    ("empty function", empty "let run = () => ()");
    ("empty record return is meaningful", clean "let run = () => {}");
    ( "multiple parameters yield one empty finding",
      empty "let run = (a, b) => ()" );
    ("typed intentional no-op", clean "let run = (): unit => ()");
    ("typed no-op block", clean "let run = (): unit => {}");
    ("unit-valued block", empty "let run = () => {()}");
    ("non-unit annotation does not exempt", empty "let run = (): other => ()");
    ("meaningful body", clean "let run = () => Console.log(1)");
    ("empty async function", empty "let run = async () => ()");
    ("returned empty function", empty "let run = () => () => ()");
    ( "meaningful block ending in unit",
      clean "let run = () => {Console.log(1); ()}" );
    ("empty file", check [ "no-empty-file" ] "");
    ("whitespace file", check [ "no-empty-file" ] " \n\t");
    ("comment-only file", check [ "no-empty-file" ] "// explanation\n");
    ( "module-attribute-only file",
      check [ "no-empty-file" ] "@@warning(\"-44\")" );
    ("empty interface", check ~kind:Source.Interface [] "");
    ("interface declaration", check ~kind:Source.Interface [] "let value: int");
    ("effect-only implementation", clean "Console.log(1)");
    ("declaration", clean "let value = 1");
    ("TODO comment", warning "// TODO: finish\nlet value = 1");
    ("case-insensitive warning", warning "// fixme: finish\nlet value = 1");
    ("block warning", warning "/* HACK: temporary */\nlet value = 1");
    ("doc warning", warning "/** TODO: finish */\nlet value = 1");
    ("module doc warning", warning "/*** TODO: finish */\nlet value = 1");
    ("non-warning documentation", clean "/** Completed work. */\nlet value = 1");
    ( "explicit doc annotation is not a comment",
      clean "@res.doc(\"TODO\") let value = 1" );
    ( "standalone attributes do not contain executable functions",
      check [ "no-empty-file" ] "@@example(() => ())" );
    ( "record field documentation is inspected",
      warning "type value = {/** TODO */ field: int}" );
    ( "warning in interface",
      check ~kind:Source.Interface [ "no-warning-comments" ]
        "// TODO\nlet value: int" );
    ( "multiple terms one finding",
      warning "// FIXME TODO HACK TODO\nlet value = 1" );
    ( "one finding per comment",
      check
        [ "no-warning-comments"; "no-warning-comments" ]
        "// TODO\nlet value = 1 // HACK\n" );
    ( "warning in empty file",
      check [ "no-empty-file"; "no-warning-comments" ] "// TODO\n" );
    ("strings are not comments", clean "let value = \"// TODO: FIXME HACK\"");
    ( "whole-word matching",
      clean "// TODOS NOTODO TODO_ HACKER FIXME2\nlet value = 1" );
    ("unicode adjacent text", clean "// TODO\195\169\nlet value = 1");
    ("non-warning comment", clean "// Completed work\nlet value = 1");
    ( "parameter boundary",
      check ~limits:params [] "let run = (first, second) => first + second" );
    ( "too many parameters",
      check ~limits:params [ "max-params" ]
        "let run = (first, second, third) => first + second + third" );
    ( "labeled parameters count once",
      check ~limits:params [ "max-params" ]
        "let run = (~first, ~second, ~third) => first + second + third" );
    ( "optional parameters count once",
      check ~limits:params [ "max-params" ]
        "let run = (~first=1, ~second=2, ~third=3) => first + second + third" );
    ( "curried functions count independently",
      check ~limits:params []
        "let run = (first, second) => (third, fourth) => first + second + \
         third + fourth" );
    ( "returned function exceeds parameters",
      check ~limits:params [ "max-params" ]
        "let run = first => (second, third, fourth) => first + second + third \
         + fourth" );
    ( "default callback gets checked",
      check ~limits:params [ "max-params" ]
        "let run = (~callback=(first, second, third) => first + second + \
         third) => callback" );
    ( "unit argument excluded",
      check ~limits:{ params with max_params = 0 } [] "let run = () => 1" );
    ( "tuple destructuring is one parameter",
      check
        ~limits:{ params with max_params = 1 }
        [] "let run = ((first, second)) => first + second" );
    ("function line boundary", check ~limits:lines [] "let run = () => {\n1}");
    ( "function exceeds line limit",
      check ~limits:lines [ "max-lines-per-function" ] "let run = () => {\n1\n}"
    );
    ( "blank lines counted",
      check ~limits:lines [ "max-lines-per-function" ] "let run = () => {\n\n1}"
    );
    ( "function parameters are not separate spans",
      check ~limits:lines
        [ "max-lines-per-function" ]
        "let run = (first, second) => {\nfirst + second\n}" );
    ( "top-level lines do not count",
      check ~limits:lines [] "let first = 1\nlet second = 2\nlet third = 3" );
    ( "control-flow boundary",
      check ~limits:nesting [] "if ready {run()} else {wait()}" );
    ( "nested conditional",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {if active {run()} else {wait()}} else {stop()}" );
    ( "else-if chains retain depth",
      check ~limits:nesting []
        "if ready {run()} else if active {wait()} else {stop()}" );
    ( "nested else body",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {run()} else {let value = 1; if active {wait()} else \
         {stop()}}" );
    ( "deep nesting reported at first excess",
      check ~limits:nesting [ "max-nesting" ]
        "if ready {if active {if valid {run()}}}" );
    ( "switch nesting",
      check ~limits:nesting [ "max-nesting" ]
        "switch value {| Some(x) => if ready {x} else {0} | None => 0}" );
    ( "while nesting",
      check ~limits:nesting [ "max-nesting" ] "while ready {if active {run()}}"
    );
    ( "for nesting",
      check ~limits:nesting [ "max-nesting" ]
        "for i in 0 to 10 {if active {run(i)}}" );
    ( "try nesting",
      check ~limits:nesting [ "max-nesting" ]
        "try {if active {run()}} catch {| _ => recover()}" );
    ( "functions reset nesting",
      check ~limits:nesting []
        "if ready {let run = () => {if active {work()}}; run()}" );
    ( "module and record nesting excluded",
      check ~limits:nesting []
        "module Example = {let value = {field: if ready {1} else {2}}}" );
    ("empty-file location", check_range "no-empty-file" 1 1 1 1 " \n");
    ( "comment location",
      check_range "no-warning-comments" 1 1 1 8 "// TODO\nlet value = 1" );
    ( "function location",
      check_range "no-empty-function" 1 11 1 19 "let run = () => ()" );
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
