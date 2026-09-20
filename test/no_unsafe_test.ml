open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "unsafe.res"; text; kind }

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

let banned text = check [ "no-unsafe" ] text
let clean text = check [] text
let expect name passed = (name, if passed then Ok () else Error name)

let exact_range =
  match
    Linter.lint_source (source "// comment\n  Option.getUnsafe(None)\n")
  with
  | Ok [ diagnostic ] ->
      diagnostic
      = Diagnostic.
          {
            filename = "unsafe.res";
            rule = "no-unsafe";
            fixes = [];
            message =
              "Do not use Option.getUnsafe. Use a checked API or explicit \
               pattern matching.";
            range =
              {
                start = { line = 2; column = 3; byte_offset = 13 };
                finish = { line = 2; column = 19; byte_offset = 29 };
              };
          }
  | _ -> false

let utf8_range =
  match
    Linter.lint_source
      (source "let text = \"\195\169\"; Option.getUnsafe(Some(text))")
  with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.column = 18
      && diagnostic.range.start.byte_offset = 17
      && diagnostic.range.finish.column = 34
      && diagnostic.range.finish.byte_offset = 33
  | _ -> false

let invalid_source =
  match Linter.lint_source (source "Option.getUnsafe(None)\nlet =") with
  | Error (Lint_error.Parse_errors _) -> true
  | _ -> false

let checks =
  [
    ("None", banned "Option.getUnsafe(None)");
    ("Some", banned "Option.getUnsafe(Some(42))");
    ("dynamic argument", banned "Option.getUnsafe(value)");
    ("pipe", banned "None->Option.getUnsafe");
    ( "known-present branch",
      banned "switch value {| Some(_) => Option.getUnsafe(value) | None => 0}"
    );
    ("try does not exempt", banned "try Option.getUnsafe(None) catch {| _ => 0}");
    ( "exception switch does not exempt",
      banned
        "switch Option.getUnsafe(None) {| value => value | exception _ => 0}" );
    ("value alias reported once", banned "let get = Option.getUnsafe\nget(None)");
    ("callback reference", banned "values->Array.map(Option.getUnsafe)");
    ( "nested call",
      check
        [ "no-unsafe"; "no-unsafe" ]
        "Option.getUnsafe(Some(Array.getUnsafe(values, 0)))" );
    ( "all rules in source order",
      check
        [ "no-unsafe"; "no-object-magic"; "no-console"; "no-unsafe" ]
        "Option.getUnsafe(Obj.magic(value))\n\
         Console.log(Array.getUnsafe(values, 0))" );
    ( "pattern matching",
      clean "switch value {| Some(value) => value | None => 0}" );
    ( "checked reads",
      clean
        "Array.get(values, 0)\n\
         Dict.get(dict, key)\n\
         String.get(text, 0)\n\
         Option.getOr(value, 0)" );
    ("throwing is a separate policy", clean "Option.getOrThrow(value)");
    ( "comments and strings",
      clean
        "// Option.getUnsafe(None)\n\
         /* Belt.Array.getUnsafe */\n\
         let text = \"Js.Dict.unsafeGet\"" );
    ("raw JavaScript stays opaque", clean "%%raw(`Option.getUnsafe(null)`)");
    ( "unrelated functions",
      clean
        "let getUnsafe = x => x\n\
         getUnsafe(None)\n\
         Custom.getUnsafe(None)\n\
         Custom.Option.getUnsafe(None)" );
    ( "wrong namespaces",
      clean
        "Js.Option.getUnsafe(None)\n\
         Option.unsafe_get(None)\n\
         Stdlib.Belt.Option.getUnsafe(None)" );
    ( "hidden implementation helpers",
      clean
        "Array.makeUninitializedUnsafe(1)\n\
         Array.truncateToLengthUnsafe(values, 1)\n\
         Array.swapUnsafe(values, 0, 1)\n\
         List.unsafeMutateTail(a, b)\n\
         Belt.Array.swapUnsafe(a, 0, 1)\n\
         Js.Dict.unsafeCreate(1)" );
    ( "ordinary module shadow",
      clean "module Option = {let getUnsafe = x => x}\nOption.getUnsafe(None)"
    );
    ( "namespace shadow",
      clean "module Stdlib = Other\nStdlib.Option.getUnsafe(None)" );
    ( "legacy namespace shadow",
      clean "module Js = Other\nJs.Dict.unsafeGet(dict, key)" );
    ( "Belt namespace shadow",
      clean "module Belt = Other\nBelt.Option.getUnsafe(None)" );
    ( "shadow not retroactive",
      banned
        "Option.getUnsafe(None)\nmodule Option = Other\nOption.getUnsafe(None)"
    );
    ( "initializer sees outer scope",
      banned "module Option = {let value = Option.getUnsafe(None)}" );
    ( "nested shadow does not escape",
      banned
        "module Nested = {module Option = Other\n\
         let value = Option.getUnsafe(None)}\n\
         Option.getUnsafe(None)" );
    ( "local module shadow",
      banned
        "let f = () => {module Option = Other\n\
         Option.getUnsafe(None)}\n\
         Option.getUnsafe(None)" );
    ( "functor parameter shadow",
      clean
        "module F = (Option: {let getUnsafe: option<int> => int}) => {let \
         value = Option.getUnsafe(None)}" );
    ( "recursive module shadow",
      clean
        "module rec Option: {let getUnsafe: option<int> => int} = {let \
         getUnsafe = x => Option.getUnsafe(x)}" );
    ( "shadow applies only to its root",
      banned
        "module Option = Other\n\
         Option.getUnsafe(None)\n\
         Stdlib.Option.getUnsafe(None)" );
    ( "interface declarations",
      check ~kind:Source.Interface []
        "module Option: {let getUnsafe: option<'a> => 'a}" );
    ( "annotation payload stays opaque",
      clean
        "@deprecated({reason: \"test\", migrate: Option.getUnsafe()})\n\
         let value = 42" );
    expect "exact location and actionable message" exact_range;
    expect "UTF-8 byte positions" utf8_range;
    expect "invalid source rejected before rules" invalid_source;
  ]

let reference_checks =
  List.map
    (fun path -> (path, banned ("let reference = " ^ path)))
    [
      "Stdlib.Option.getUnsafe";
      "Stdlib_Option.getUnsafe";
      "Stdlib.Array.setUnsafe";
      "Stdlib_Array.unsafe_get";
      "Null.getUnsafe";
      "Nullable.getUnsafe";
      "Dict.getUnsafe";
      "String.getUnsafe";
      "Object.getSymbolUnsafe";
      "String.charCodeAtUnsafe";
      "Array.joinUnsafe";
      "Js.Null.getUnsafe";
      "Js.Undefined.getUnsafe";
      "Js_undefined.getUnsafe";
      "Belt.Option.getUnsafe";
      "Belt_Option.getUnsafe";
      "Belt.Array.makeUninitializedUnsafe";
      "Belt.Array.blitUnsafe";
      "Belt.Set.fromSortedArrayUnsafe";
      "Belt.Set.Int.fromSortedArrayUnsafe";
      "Belt_Set.String.fromSortedArrayUnsafe";
      "Belt_SetDict.fromSortedArrayUnsafe";
      "Belt.MutableSet.String.fromSortedArrayUnsafe";
      "Js.Array.unsafe_get";
      "Js.Array2.unsafe_set";
      "Js.Dict.unsafeGet";
      "Js.Dict.unsafeDeleteKey";
      "Js.Json.deserializeUnsafe";
      "Js.Date.toJSONUnsafe";
      "Js.Math.unsafe_floor_int";
      "Js.String2.unsafeReplaceBy3";
      "Js.String.unsafeReplaceBy0";
      "Js.Promise2.unsafe_await";
      "Js.unsafe_lt";
      "Js_OO.unsafe_to_method";
      "Char.unsafe_chr";
      "Pervasives.__unsafe_cast";
      "Js.Typed_array.Int8Array.unsafe_get";
      "Js.TypedArray2.Float64Array.unsafe_set";
      "Js_typed_array.Int32_array.unsafe_get";
      "Js_typed_array2.Uint32Array.unsafe_set";
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ reference_checks)
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
