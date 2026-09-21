open Rescript_linter

let directory = "../vendor/rescript/packages/@rescript/runtime"

let expected_members =
  [
    "parseExn";
    "parseExnWithReviver";
    "parseOrThrow";
    "stringifyAny";
    "stringifyAnyWithFilter";
    "stringifyAnyWithFilterAndIndent";
    "stringifyAnyWithIndent";
    "stringifyAnyWithReplacer";
    "stringifyAnyWithReplacerAndIndent";
  ]

let read_all () =
  let files =
    try Ok (Sys.readdir directory |> Array.to_list |> List.sort String.compare)
    with Sys_error detail -> Error detail
  in
  Result.bind files (fun files ->
      List.filter
        (fun name -> List.mem (Filename.extension name) [ ".res"; ".resi" ])
        files
      |> List.fold_left
           (fun result filename ->
             Result.bind result (fun parsed ->
                 let tree =
                   Result.bind
                     (Source.read (Filename.concat directory filename))
                     Parser.parse
                 in
                 Result.map_error Lint_error.render tree
                 |> Result.map (fun tree -> (filename, tree) :: parsed)))
           (Ok []))

let annotation_count tree =
  let count = ref 0 in
  let visitor =
    {
      Ast_iterator.default_iterator with
      attribute =
        (fun _ attribute ->
          if Throws_annotation.is_throws attribute then incr count);
    }
  in
  (match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items);
  !count

let declarations = function
  | Parser.Implementation items ->
      List.filter_map
        (fun item ->
          match item.Parsetree.pstr_desc with
          | Pstr_primitive declaration -> Some declaration
          | _ -> None)
        items
  | Interface items ->
      List.filter_map
        (fun item ->
          match item.Parsetree.psig_desc with
          | Psig_value declaration -> Some declaration
          | _ -> None)
        items

let normalized_type typ =
  let mapper =
    {
      Ast_mapper.default_mapper with
      location = (fun _ _ -> Location.none);
      typ =
        (fun self typ ->
          let mapped = Ast_mapper.default_mapper.typ self typ in
          match mapped.Parsetree.ptyp_desc with
          | Ptyp_arrow { arg; ret; arity } ->
              let lbl =
                match arg.lbl with
                | Asttypes.Nolabel -> Asttypes.Nolabel
                | Labelled name -> Labelled { name with loc = Location.none }
                | Optional name -> Optional { name with loc = Location.none }
              in
              let arg =
                { arg with lbl; attrs = self.attributes self arg.attrs }
              in
              { mapped with ptyp_desc = Ptyp_arrow { arg; ret; arity } }
          | _ -> mapped);
    }
  in
  mapper.typ mapper typ

let parsed_type prefix text =
  let source =
    Source.
      {
        filename = "type.res";
        kind = Implementation;
        text = prefix ^ "@val external read: " ^ text ^ " = \"read\"";
      }
  in
  Result.map
    (fun tree ->
      List.map
        (fun declaration -> declaration.Parsetree.pval_type)
        (declarations tree))
    (Parser.parse source)

let compare_types expected left right =
  match (parsed_type "" left, parsed_type "\n\n" right) with
  | Ok [ left ], Ok [ right ] ->
      normalized_type left = normalized_type right = expected
  | _ -> false

let normalization_checks =
  [
    ( "normalize only optional-label location",
      compare_types true "(~value: int=?, unit) => int"
        "(~value: int=?, unit) => int" );
    ( "normalize only mandatory-label location",
      compare_types true "(~value: int, unit) => int"
        "(~value: int, unit) => int" );
    ( "preserve label spelling",
      compare_types false "(~left: int, unit) => int"
        "(~right: int, unit) => int" );
    ( "preserve label optionalness",
      compare_types false "(~value: int=?, unit) => int"
        "(~value: int, unit) => int" );
    ( "preserve parameter type",
      compare_types false "(~value: int, unit) => int"
        "(~value: string, unit) => int" );
    ( "preserve direct function arity",
      compare_types false "(int, int) => int" "int => (int => int)" );
    ( "preserve FFI argument attribute payload",
      compare_types false "(@as(json`null`) _, int) => int"
        "(@as(0) _, int) => int" );
  ]

let rec result_type remaining typ =
  match typ.Parsetree.ptyp_desc with
  | Ptyp_arrow { ret; _ } when remaining > 0 -> result_type (remaining - 1) ret
  | _ -> typ

let synchronous_result declaration =
  match declaration.Parsetree.pval_type.ptyp_desc with
  | Ptyp_arrow { arity; _ } -> (
      let result =
        result_type (Option.value ~default:1 arity) declaration.pval_type
      in
      match result.ptyp_desc with
      | Ptyp_constr ({ txt = Longident.Lident ("t" | "string"); _ }, []) -> true
      | Ptyp_constr
          ( { txt = Longident.Lident "option"; _ },
            [
              {
                ptyp_desc =
                  Ptyp_constr ({ txt = Longident.Lident "string"; _ }, []);
                _;
              };
            ] ) ->
          true
      | _ -> false)
  | _ -> false

let contract_checks interfaces declaration =
  let name = declaration.Parsetree.pval_name.txt in
  let primitive =
    if String.starts_with ~prefix:"parse" name then "JSON.parse"
    else "JSON.stringify"
  in
  let source =
    [
      ( name ^ ": bare source contract",
        Throws_annotation.decode declaration.pval_attributes = Ok (Some Any) );
      ( name ^ ": global external binding",
        Semantic_model.has_attribute "val" declaration.pval_attributes );
      (name ^ ": direct synchronous return", synchronous_result declaration);
    ]
  in
  match
    List.find_opt
      (fun public -> public.Parsetree.pval_name.txt = name)
      interfaces
  with
  | None -> (name ^ ": missing public declaration", false) :: source
  | Some public ->
      [
        ( name ^ ": primitive identity",
          public.pval_prim = [ primitive ]
          && declaration.pval_prim = public.pval_prim );
        ( name ^ ": normalized public/source core type",
          normalized_type declaration.pval_type
          = normalized_type public.pval_type );
        ( name ^ ": public annotation is absent",
          Throws_annotation.decode public.pval_attributes = Ok None );
      ]
      @ source

let alias tree local target =
  match tree with
  | Parser.Implementation items ->
      List.exists
        (fun item ->
          match item.Parsetree.pstr_desc with
          | Pstr_module
              { pmb_name; pmb_expr = { pmod_desc = Pmod_ident name; _ }; _ } ->
              pmb_name.txt = local && name.txt = Longident.Lident target
          | _ -> false)
        items
  | Interface _ -> false

let upstream_checks trees =
  let find filename =
    Option.value ~default:(Parser.Implementation [])
      (List.assoc_opt filename trees)
  in
  let implementation =
    declarations (find "Stdlib_JSON.res")
    |> List.filter (fun declaration ->
        List.exists Throws_annotation.is_throws
          declaration.Parsetree.pval_attributes)
  in
  let interface = declarations (find "Stdlib_JSON.resi") in
  let counts =
    List.filter_map
      (fun (filename, tree) ->
        let count = annotation_count tree in
        if count = 0 then None else Some (filename, count))
      trees
  in
  [
    ( "all runtime annotations are the nine known source contracts",
      counts = [ ("Stdlib_JSON.res", 9) ] );
    ( "exact source contract inventory",
      List.map
        (fun declaration -> declaration.Parsetree.pval_name.txt)
        implementation
      |> List.sort String.compare = expected_members );
    ( "Stdlib exposes modern JSON module",
      alias (find "Stdlib.res") "JSON" "Stdlib_JSON" );
    ( "legacy Js.Json remains a distinct module",
      alias (find "Js.res") "Json" "Js_json" );
  ]
  @ List.concat_map (contract_checks interface) implementation

let is_annotated path =
  Throws_scope.value Throws_runtime.scope path = Some (Annotated Any)

let is_plain path = Throws_scope.value Throws_runtime.scope path = Some Plain

let opaque path =
  match Throws_scope.module_scope Throws_runtime.scope path with
  | Some scope -> Throws_scope.is_opaque scope
  | None -> false

let rec prefix parent path =
  match (parent, path) with
  | [], _ -> true
  | first :: rest, current :: tail when first = current -> prefix rest tail
  | _ -> false

let opaque_parent path =
  List.exists
    (fun (parent, opaque, _) ->
      opaque && List.length parent < List.length path && prefix parent path)
    Banned_runtime_data.modules

let all_public_rows =
  List.for_all
    (fun (path, is_opaque, names) ->
      match Throws_scope.module_scope Throws_runtime.scope path with
      | None -> opaque_parent path
      | Some scope when is_opaque ->
          Throws_scope.is_opaque scope
          && List.for_all
               (fun name -> Throws_scope.value scope [ name ] = None)
               names
      | Some scope ->
          List.for_all
            (fun name ->
              let full = path @ [ name ] in
              Throws_scope.value scope [ name ]
              = Some
                  (if List.mem full Throws_runtime.annotated_paths then
                     Annotated Any
                   else Plain))
            names)
    Banned_runtime_data.modules

let checks =
  [
    ( "exactly twenty-seven public contract paths",
      List.length Throws_runtime.annotated_paths = 27 );
    ( "all adapted public paths resolve",
      List.for_all is_annotated Throws_runtime.annotated_paths );
    ( "ordinary JSON stringify remains unannotated",
      is_plain [ "JSON"; "stringify" ] );
    ("legacy parse remains unannotated", is_plain [ "Js"; "Json"; "parseExn" ]);
    ( "legacy stringifyAny remains unannotated",
      is_plain [ "Js_json"; "stringifyAny" ] );
    ("console export is known but unannotated", is_plain [ "Console"; "log" ]);
    ("all public shape rows preserve contract classification", all_public_rows);
    ("functor shape stays opaque", opaque [ "Belt_Id"; "MakeComparable" ]);
    ( "opaque event include retains no guessed values",
      opaque [ "JsxEvent"; "Mouse" ]
      && Throws_scope.value Throws_runtime.scope
           [ "JsxEvent"; "Mouse"; "clientX" ]
         = None );
    ( "implementation-only banned compatibility spelling is absent",
      Throws_scope.value Throws_runtime.scope [ "Primitive_object"; "magic" ]
      = None );
    ( "builtin exception identities survive autoopen",
      Throws_scope.exception_id Throws_runtime.scope [ "Not_found" ]
      = Some "builtin:Not_found" );
  ]

let () =
  match read_all () with
  | Error message ->
      prerr_endline message;
      exit 1
  | Ok trees -> (
      let checks = checks @ normalization_checks @ upstream_checks trees in
      let failures =
        List.filter_map
          (fun (name, passed) -> if passed then None else Some name)
          checks
      in
      match failures with
      | [] ->
          Printf.printf "throws runtime inventory: %d checks passed\n"
            (List.length checks)
      | _ ->
          List.iter prerr_endline failures;
          exit 1)
