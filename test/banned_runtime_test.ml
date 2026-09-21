open Rescript_linter

let rec identifier = function
  | [] -> Longident.Lident ""
  | [ name ] -> Longident.Lident name
  | names -> (
      let reversed = List.rev names in
      match reversed with
      | [] -> Longident.Lident ""
      | last :: rest -> Longident.Ldot (identifier (List.rev rest), last))

let runtime_path names =
  match Semantic_model.resolve Banned_runtime.scope (identifier names) with
  | Some value -> value.api = Some names && value.canonical = Some names
  | None -> false

let canonical_paths =
  [
    [ "Obj"; "magic" ];
    [ "Primitive_object"; "magic" ];
    [ "Primitive_object_extern"; "magic" ];
    [ "Console"; "log" ];
    [ "Stdlib"; "Console"; "log" ];
    [ "Stdlib_Console"; "log" ];
    [ "Js"; "Console"; "log" ];
    [ "Js_console"; "log" ];
    [ "Js"; "log" ];
    [ "Option"; "getUnsafe" ];
    [ "Stdlib"; "Option"; "getUnsafe" ];
    [ "Stdlib_Option"; "getUnsafe" ];
    [ "Js"; "Math"; "log" ];
    [ "Math"; "log" ];
    [ "Belt"; "Set"; "Int"; "fromSortedArrayUnsafe" ];
    [ "Belt_Set"; "Int"; "fromSortedArrayUnsafe" ];
    [ "Belt_SetInt"; "fromSortedArrayUnsafe" ];
    [ "Js"; "Typed_array"; "Int32_array"; "unsafe_get" ];
    [ "Js_typed_array"; "Int32Array"; "unsafe_get" ];
    [ "Js"; "TypedArray2"; "Float64Array"; "unsafe_set" ];
    [ "panic" ];
    [ "Stdlib"; "panic" ];
  ]

let check name condition = (name, if condition then Ok () else Error "failed")

let parity =
  match
    Runtime_exports.read
      ~directory:"../vendor/rescript/packages/@rescript/runtime"
  with
  | Error error -> Error (Lint_error.render error)
  | Ok actual ->
      if actual = Banned_runtime_data.modules then Ok ()
      else
        Error
          "Generated runtime shapes differ from pinned sources; rerun \
           scripts/generate_banned_runtime.exe."

let safe_open_shadow =
  let scope =
    Semantic_model.open_path Banned_runtime.scope (identifier [ "Console" ])
  in
  let scope = Semantic_model.open_path scope (identifier [ "Js"; "Math" ]) in
  match Semantic_model.resolve scope (identifier [ "log" ]) with
  | Some { api = Some path; _ } ->
      path = [ "Js"; "Math"; "log" ] && No_console.rule.message path = None
  | _ -> false

let source_tree name kind text =
  Result.map_error Lint_error.render
    (Parser.parse Source.{ filename = name; kind; text })

let fixture units expected =
  let parsed =
    List.fold_left
      (fun result (name, kind, text) ->
        Result.bind result (fun units ->
            Result.map
              (fun tree -> (name, tree) :: units)
              (source_tree name kind text)))
      (Ok []) units
  in
  Result.bind parsed (fun units ->
      let actual = Runtime_exports.entries units in
      if actual = expected then Ok () else Error (Runtime_exports.render actual))

let implementation name text = (name, Source.Implementation, text)
let interface name text = (name, Source.Interface, text)

let fixture_checks =
  [
    ( "source exports omit locals and documentation",
      fixture
        [
          implementation "Api"
            "@@example(let hidden = 1)\n\
             let visible = () => {let local = 1; local}\n\
             @val external externalValue: int = \"externalValue\"\n\
             type t = int";
        ]
        [ ([ "Api" ], false, [ "externalValue"; "visible" ]) ] );
    ( "tuple and constrained binding exports",
      fixture
        [
          implementation "Api"
            "let (first, second) = (1, 2)\nlet third: int = 3";
        ]
        [ ([ "Api" ], false, [ "first"; "second"; "third" ]) ] );
    ( "cross-file alias fixed point",
      fixture
        [
          implementation "Facade" "module Nested = Provider.Values";
          implementation "Provider" "module Values = {let read = () => 1}";
        ]
        [
          ([ "Facade" ], false, []);
          ([ "Facade"; "Nested" ], false, [ "read" ]);
          ([ "Provider" ], false, []);
          ([ "Provider"; "Values" ], false, [ "read" ]);
        ] );
    ( "include respects declaration-time scope",
      fixture
        [
          implementation "Api"
            "module Source = {let first = 1}\n\
             include Source\n\
             module Source = {let second = 2}";
        ]
        [
          ([ "Api" ], false, [ "first" ]);
          ([ "Api"; "Source" ], false, [ "second" ]);
        ] );
    ( "open is not re-exported",
      fixture
        [
          implementation "Api"
            "module Source = {let hidden = 1}\n\
             open Source\n\
             let visible = hidden";
        ]
        [
          ([ "Api" ], false, [ "visible" ]);
          ([ "Api"; "Source" ], false, [ "hidden" ]);
        ] );
    ( "unknown include quarantines earlier exports",
      fixture
        [
          implementation "Api" "let before = 1\ninclude Missing\nlet after = 2";
        ]
        [ ([ "Api" ], true, [ "after" ]) ] );
    ( "constrained module hides private values",
      fixture
        [
          implementation "Api"
            "module Nested: {let visible: int} = {let hidden = 1; let visible \
             = 2}";
        ]
        [ ([ "Api" ], false, []); ([ "Api"; "Nested" ], false, [ "visible" ]) ]
    );
    ( "local module type retains exports",
      fixture
        [
          implementation "Api"
            "module type S = {let visible: int}\n\
             module Nested: S = {let hidden = 1; let visible = 2}";
        ]
        [ ([ "Api" ], false, []); ([ "Api"; "Nested" ], false, [ "visible" ]) ]
    );
    ( "functors stay opaque",
      fixture
        [
          implementation "Api" "module Build = (Input: {}) => {let hidden = 1}";
        ]
        [ ([ "Api" ], false, []); ([ "Api"; "Build" ], true, []) ] );
    ( "signature include and alias",
      fixture
        [
          interface "Api"
            "module Source: {let read: unit => int}\n\
             include module type of Source\n\
             module Alias = Source";
        ]
        [
          ([ "Api" ], false, [ "read" ]);
          ([ "Api"; "Alias" ], false, [ "read" ]);
          ([ "Api"; "Source" ], false, [ "read" ]);
        ] );
    ( "signature local module type",
      fixture
        [
          interface "Api"
            "module type S = {let read: unit => int}\nmodule Nested: S";
        ]
        [ ([ "Api" ], false, []); ([ "Api"; "Nested" ], false, [ "read" ]) ] );
    ( "signature open is lexical",
      fixture
        [
          interface "Api"
            "module Source: {module type S = {let read: unit => int}}\n\
             open Source\n\
             module Nested: S";
        ]
        [
          ([ "Api" ], false, []);
          ([ "Api"; "Nested" ], false, [ "read" ]);
          ([ "Api"; "Source" ], false, []);
        ] );
    ( "signature unknown module type",
      fixture
        [ interface "Api" "module Nested: Missing" ]
        [ ([ "Api" ], false, []); ([ "Api"; "Nested" ], true, []) ] );
    ( "alias cycles stay opaque",
      fixture
        [
          implementation "First" "include Second";
          implementation "Second" "include First";
        ]
        [ ([ "First" ], true, []); ([ "Second" ], true, []) ] );
  ]

let checks =
  ("pinned source parity", parity)
  :: check "implementation magic compatibility ban is separate from public data"
       (runtime_path [ "Primitive_object"; "magic" ]
       && List.exists
            (fun (path, _, names) ->
              path = [ "Primitive_object" ] && not (List.mem "magic" names))
            Banned_runtime_data.modules)
  :: check "safe runtime open shadows banned name" safe_open_shadow
  :: check "hidden array implementation module absent"
       (Semantic_model.module_path Banned_runtime.scope [ "Stdlib_Array"; "M" ]
       = None)
  :: check "hidden list implementation module absent"
       (Semantic_model.module_path Banned_runtime.scope [ "Stdlib_List"; "A" ]
       = None)
  :: (List.map
        (fun path -> check (String.concat "." path) (runtime_path path))
        canonical_paths
     @ fixture_checks)

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  match failures with
  | [] ->
      Printf.printf "banned runtime: %d checks passed\n" (List.length checks)
  | _ ->
      List.iter prerr_endline failures;
      exit 1
