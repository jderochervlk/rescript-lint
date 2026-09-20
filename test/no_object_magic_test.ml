open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "magic.res"; text; kind }

let check ?kind expected text =
  match Linter.lint_source (source ?kind text) with
  | Ok diagnostics ->
      let rules = List.map (fun (d : Diagnostic.t) -> d.rule) diagnostics in
      if rules = expected then Ok ()
      else
        Error
          ("Unexpected diagnostics for " ^ text ^ ": "
          ^ String.concat "; " (List.map Diagnostic.render diagnostics))
  | Error error -> Error (Lint_error.render error)

let banned text = check [ "no-object-magic" ] text
let clean text = check [] text
let expect name passed = (name, if passed then Ok () else Error name)

let exact_range =
  match Linter.lint_source (source "// comment\n  Obj.magic(42)\n") with
  | Ok [ diagnostic ] ->
      diagnostic
      = Diagnostic.
          {
            filename = "magic.res";
            rule = "no-object-magic";
            message =
              "Do not use Obj.magic. Use a typed conversion or validate the \
               input.";
            range =
              {
                start = { line = 2; column = 3; byte_offset = 13 };
                finish = { line = 2; column = 12; byte_offset = 22 };
              };
          }
  | _ -> false

let utf8_range =
  match
    Linter.lint_source (source "let text = \"\195\169\"; Obj.magic(text)")
  with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.column = 18
      && diagnostic.range.start.byte_offset = 17
      && diagnostic.range.finish.column = 27
      && diagnostic.range.finish.byte_offset = 26
  | _ -> false

let invalid_source =
  match Linter.lint_source (source "Obj.magic(1)\nlet =") with
  | Error (Lint_error.Parse_errors _) -> true
  | _ -> false

let checks =
  [
    ("call", banned "let value = Obj.magic(42)");
    ("pipe", banned "let value = 42->Obj.magic");
    ( "value alias reported once",
      banned "let cast = Obj.magic\nlet value = cast(42)" );
    ("higher-order reference", banned "let values = items->Array.map(Obj.magic)");
    ("nested function", banned "let cast = () => {Obj.magic(42)}");
    ("conditional", banned "let value = if flag {Obj.magic(42)} else {other}");
    ( "try does not exempt cast",
      banned "let value = try Obj.magic(42) catch {| _ => 0}" );
    ( "exception switch does not exempt cast",
      banned
        "let value = switch Obj.magic(42) {| value => value | exception _ => 0}"
    );
    ( "multiple casts",
      check [ "no-object-magic"; "no-object-magic" ] "Obj.magic(Obj.magic(42))"
    );
    ( "mixed rules ordered by source",
      check
        [ "no-object-magic"; "no-console"; "no-console"; "no-object-magic" ]
        "Obj.magic(Console.log(1))\nConsole.warn(Obj.magic(2))" );
    ( "comments and strings",
      clean
        "// Obj.magic(1)\n\
         /* Primitive_object.magic(2) */\n\
         let text = \"Obj.magic(3)\"" );
    ("raw JavaScript stays opaque", clean "%%raw(`Obj.magic(42)`)");
    ( "unrelated magic functions",
      clean
        "let magic = x => x\n\
         let value = magic(42)\n\
         Other.magic(42)\n\
         Other.Obj.magic(42)" );
    ("other Obj members", clean "let value = Obj.repr(42)");
    ( "JavaScript Object API",
      clean "let object = Object.make()\nObject.keysToArray(object)" );
    ( "unsupported namespace spellings",
      clean
        "Object.magic(1)\nStdlib.Obj.magic(1)\nJs.Obj.magic(1)\nJs_obj.magic(1)"
    );
    ( "ordinary module shadow",
      clean "module Obj = {let magic = x => x}\nObj.magic(42)" );
    ("shadow from module alias", clean "module Obj = Other\nObj.magic(42)");
    ( "shadow not retroactive",
      banned "Obj.magic(1)\nmodule Obj = Other\nObj.magic(2)" );
    ( "initializer sees outer scope",
      banned "module Obj = {let value = Obj.magic(1)}" );
    ( "nested shadow does not escape",
      banned
        "module Nested = {module Obj = Other\n\
         let value = Obj.magic(1)}\n\
         Obj.magic(2)" );
    ( "block-local shadow",
      banned "let f = () => {module Obj = Other\nObj.magic(1)}\nObj.magic(2)" );
    ( "functor parameter shadow",
      clean
        "module F = (Obj: {let magic: int => int}) => {let value = \
         Obj.magic(1)}" );
    ( "recursive module shadow",
      clean
        "module rec Obj: {let magic: int => int} = {let magic = x => \
         Obj.magic(x)}" );
    ( "shadow applies only to its root",
      banned "module Obj = Other\nObj.magic(1)\nPrimitive_object.magic(2)" );
    ( "interface declarations",
      check ~kind:Source.Interface []
        "module Obj: {let magic: 'a => 'a}\nlet cast: int => string" );
    ( "annotation payload stays opaque",
      clean
        "@deprecated({reason: \"test\", migrate: Obj.magic()})\nlet value = 42"
    );
    expect "qualified identifier range and actionable message" exact_range;
    expect "UTF-8 range" utf8_range;
    expect "invalid source is rejected before linting" invalid_source;
  ]

let export_checks =
  List.concat_map
    (fun root ->
      [
        (root ^ " reference", banned ("let cast = " ^ root ^ ".magic"));
        ( root ^ " shadow",
          clean ("module " ^ root ^ " = Other\n" ^ root ^ ".magic(42)") );
      ])
    [ "Obj"; "Primitive_object"; "Primitive_object_extern" ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ export_checks)
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
