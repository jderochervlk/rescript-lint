open Rescript_linter
open Semantic_model

let scope = Semantic_runtime.initial_scope default_context
let identifier names = Longident.parse (String.concat "." names)

let builtin path (arity, result, pure) =
  match resolve scope (identifier path) with
  | None -> false
  | Some value ->
      value.typ
      = Function (List.init arity (fun _ -> (Asttypes.Nolabel, Unknown)), result)
      && value.pure = pure && value.api = Some path
      && value.canonical = Some path
      && value.identity = "runtime:" ^ String.concat "." path
      && value.declaration_origin = External
      && value.expression = None && value.attributes = []

let aliases name =
  match module_path scope [ name ] with
  | None -> false
  | Some nested ->
      nested.origin = Some [ name ]
      && (not nested.opaque)
      && module_path scope [ "Stdlib_" ^ name ] = Some nested
      && module_path scope [ "Stdlib"; name ] = Some nested
      && module_path scope [ "Stdlib"; "Stdlib_" ^ name ] = Some nested

let standard name typ =
  List.for_all
    (fun path ->
      let reference = identifier (path @ [ "t" ]) in
      standard_type scope reference = Some [ name; "t" ]
      && type_provenance scope reference = External
      && type_of scope (Ast_helper.Typ.constr (Location.mknoloc reference) [])
         = typ)
    [ [ name ]; [ "Stdlib_" ^ name ]; [ "Stdlib"; name ] ]

let runtime_checks =
  [
    ( "runtime module aliases",
      List.for_all aliases
        [
          "Array";
          "List";
          "String";
          "Option";
          "Result";
          "Promise";
          "Int";
          "Console";
          "Dict";
        ] );
    ("array length metadata", builtin [ "Array"; "length" ] (1, Int, true));
    ( "list tail result",
      builtin [ "List"; "tail" ] (1, Option (List Unknown), true) );
    ( "string lookup result",
      builtin [ "String"; "get" ] (2, Option String, true) );
    ( "unsafe option lookup is pure",
      builtin [ "Option"; "getUnsafe" ] (1, Unknown, true) );
    ( "throwing result lookup is impure",
      builtin [ "Result"; "getOrThrow" ] (1, Unknown, false) );
    ( "promise result and effects",
      builtin [ "Promise"; "all" ] (1, Promise (Array Unknown), false) );
    ("console effects", builtin [ "Console"; "log" ] (1, Unit, false));
    ("integer parsing", builtin [ "Int"; "fromString" ] (1, Option Int, true));
    ( "operator metadata",
      List.for_all
        (fun (name, pure) ->
          match resolve scope (Longident.Lident name) with
          | None -> false
          | Some value ->
              value.typ
              = Function ([ (Nolabel, Unknown); (Nolabel, Unknown) ], Unknown)
              && value.pure = pure
              && value.api = Some [ "Stdlib"; name ])
        [
          ("+", true); ("not", true); ("/", false); ("==", false); ("<", false);
        ] );
    ("ignore metadata", builtin [ "Stdlib"; "ignore" ] (1, Unit, true));
    ( "standard types",
      List.for_all
        (fun (name, typ) -> standard name typ)
        [
          ("Array", Array Unknown);
          ("List", List Unknown);
          ("String", String);
          ("Option", Option Unknown);
          ("Result", Result Unknown);
          ("Promise", Promise Unknown);
          ("Int", Int);
          ("Dict", Unknown);
        ] );
    ( "constructors",
      Names.find_opt "Some" scope.constructors = Some (Option Unknown)
      && Names.find_opt "None" scope.constructors = Some (Option Unknown)
      && Names.find_opt "Ok" scope.constructors = Some (Result Unknown)
      && Names.find_opt "Error" scope.constructors = Some (Result Unknown) );
    ( "unknown bindings stay absent",
      resolve scope (identifier [ "Array"; "missing" ]) = None
      && value_provenance scope (identifier [ "Missing"; "value" ]) = Absent
      && standard_type scope (identifier [ "Console"; "t" ]) = None );
  ]

let shadowing_check =
  let shadowed =
    Semantic_runtime.initial_scope
      { default_context with project_modules = [ "Array" ] }
  in
  ( "project modules mask runtime modules",
    module_path shadowed [ "Array" ] = Some unknown
    && resolve shadowed (identifier [ "Array"; "length" ]) = None
    && value_provenance shadowed (identifier [ "Array"; "length" ])
       = Unavailable
    && standard_type shadowed (identifier [ "Array"; "t" ]) = None
    && module_path shadowed [ "Stdlib_Array" ] = module_path scope [ "Array" ]
    && module_path shadowed [ "Stdlib"; "Array" ]
       = module_path scope [ "Array" ] )

let signature_scope entries update =
  let parsed =
    List.fold_left
      (fun parsed (name, text) ->
        Result.bind parsed (fun signatures ->
            let source =
              Source.{ filename = name ^ ".resi"; text; kind = Interface }
            in
            match Parser.parse source with
            | Ok (Interface items) -> Ok ((name, items) :: signatures)
            | Ok _ -> Error "Expected interface"
            | Error error -> Error (Lint_error.render error)))
      (Ok []) (List.rev entries)
  in
  Result.map
    (fun module_signatures ->
      Semantic_runtime.initial_scope
        (update
           {
             default_context with
             module_signatures;
             project_modules = List.map fst entries;
           }))
    parsed

let check_scope result check =
  Result.bind result (fun scope ->
      if check scope then Ok () else Error "Scope contract changed")

let project_signature_check =
  check_scope
    (signature_scope
       [ ("Array", "type t = int\nlet count: t") ]
       (fun context ->
         {
           context with
           value_origins = [ ([ "Array"; "count" ], Declared_at "Array.res") ];
           type_origins =
             [
               ( [ "Array"; "t" ],
                 Declared
                   {
                     type_identity = Some [ "Array"; "t" ];
                     type_source = Some "Array.res";
                   } );
             ];
         }))
    (fun scope ->
      match resolve scope (identifier [ "Array"; "count" ]) with
      | None -> false
      | Some value ->
          value.typ = Int
          && value.canonical = Some [ "Array"; "count" ]
          && value.declaration_origin = Declared_at "Array.res"
          && resolve scope (identifier [ "Array"; "length" ]) = None
          && standard_type scope (identifier [ "Array"; "t" ]) = None
          && type_provenance scope (identifier [ "Array"; "t" ])
             = Declared_at "Array.res")

let alias_order_check =
  check_scope
    (signature_scope
       [
         ("First", "module Alias = Later");
         ("Later", "module Nested: {let value: int}\ninclude {let flag: bool}");
       ]
       Fun.id)
    (fun scope ->
      match
        resolve scope (identifier [ "First"; "Alias"; "Nested"; "value" ])
      with
      | None -> false
      | Some value ->
          value.typ = Int
          && module_identity scope (identifier [ "First"; "Alias" ])
             = Some [ "Later" ])

let namespace_check project_modules =
  check_scope
    (signature_scope
       [
         ("Package", "module Alias = Sibling\nmodule Sibling: {let value: int}");
       ]
       (fun context ->
         { context with namespace_roots = [ "Package" ]; project_modules }))
    (fun scope ->
      match resolve scope (identifier [ "Package"; "Alias"; "value" ]) with
      | None -> false
      | Some value -> value.typ = Int)

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools (runtime_checks @ [ shadowing_check ])
    @ [
        ("project signature metadata", project_signature_check);
        ("out-of-order signatures settle", alias_order_check);
        ("namespace sibling aliases settle", namespace_check [ "Package" ]);
        ("undeclared namespace roots settle", namespace_check []);
      ])
