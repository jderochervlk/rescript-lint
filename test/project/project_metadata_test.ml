open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "Metadata.res"; text; kind }

let parse ?kind text =
  Result.map_error Lint_error.render (Parser.parse (source ?kind text))

let paths tree =
  Project_exports.declarations tree
  |> List.map (fun (item : Project_exports.declaration) -> item.path)

let exports ?kind expected text =
  Result.bind (parse ?kind text) (fun tree ->
      let actual = paths tree in
      if List.sort compare actual = List.sort compare expected then Ok ()
      else
        Error
          ("Unexpected exports: "
          ^ String.concat ", " (List.map (String.concat ".") actual)))

let inferred text =
  Result.bind (parse text) (function
    | Parser.Implementation items ->
        Ok
          (Project_signatures.of_structure
             ~context:Semantic_model.default_context items)
    | Interface _ -> Error "Expected implementation")

let signature_value name signature =
  List.find_map
    (fun (item : Parsetree.signature_item) ->
      match item.psig_desc with
      | Psig_value value when value.pval_name.txt = name -> Some value
      | _ -> None)
    signature

let inferred_type expected text =
  Result.bind (inferred text) (fun signature ->
      match signature_value "value" signature with
      | Some value
        when Semantic_model.type_of Semantic_model.empty value.pval_type
             = expected ->
          Ok ()
      | _ -> Error "Generated signature lost the inferred value type")

let inferred_exports expected text =
  Result.bind (inferred text) (fun signature ->
      let actual = paths (Parser.Interface signature) in
      if List.sort compare actual = List.sort compare expected then Ok ()
      else
        Error
          ("Unexpected inferred exports: "
          ^ String.concat ", " (List.map (String.concat ".") actual)))

let public_exports interface expected =
  let implementation =
    source
      "let visible = 1\n\
       let hidden = 2\n\
       module Nested = {let visible = true; let hidden = false}"
  in
  Result.bind
    (Result.map_error Lint_error.render (Parser.parse implementation))
    (fun tree ->
      let unit_ =
        Project_files.
          { name = "Metadata"; source = implementation; tree; modified = 0. }
      in
      let project units = Project_files.{ root = "/metadata"; units } in
      let public project =
        Project_exports.public project unit_
        |> List.map (fun (item : Project_exports.declaration) -> item.path)
      in
      match interface with
      | None ->
          if public (project [ unit_ ]) = expected then Ok ()
          else Error "Unconstrained public exports mismatch"
      | Some text ->
          let source =
            Source.{ filename = "Metadata.resi"; text; kind = Interface }
          in
          Result.bind
            (Result.map_error Lint_error.render (Parser.parse source))
            (fun tree ->
              let declaration =
                Project_files.{ name = "Metadata"; source; tree; modified = 0. }
              in
              if public (project [ unit_; declaration ]) = expected then Ok ()
              else Error "Interface precedence mismatch"))

let annotation_preserved =
  Result.bind
    (inferred "@deprecated(\"use replacement\") let value: opaque = unknown")
    (fun signature ->
      match signature_value "value" signature with
      | Some value -> (
          match value.pval_type.ptyp_desc with
          | Ptyp_constr ({ txt = Lident "opaque"; _ }, [])
            when Semantic_model.has_attribute "deprecated" value.pval_attributes
                 && value.pval_loc.loc_start.pos_lnum = 1 ->
              Ok ()
          | _ -> Error "Explicit type or deprecated annotation lost")
      | None -> Error "Missing annotated value")

let external_preserved =
  Result.bind
    (inferred "@module(\"other\") external value: int => bool = \"check\"")
    (fun signature ->
      match signature_value "value" signature with
      | Some value
        when value.pval_prim = [ "check" ]
             && Semantic_model.has_attribute "module" value.pval_attributes ->
          Ok ()
      | _ -> Error "External identity or attribute lost")

let type_declaration_preserved =
  Result.bind (inferred "type status = Ready | Waiting\nlet value = Ready")
    (fun signature ->
      if
        List.exists
          (fun (item : Parsetree.signature_item) ->
            match item.psig_desc with
            | Psig_type
                ( _,
                  [
                    {
                      ptype_name = { txt = "status"; _ };
                      ptype_kind = Ptype_variant constructors;
                      _;
                    };
                  ] ) ->
                List.length constructors = 2
            | _ -> false)
          signature
      then Ok ()
      else Error "Type declaration lost")

let constrained_module =
  Result.bind
    (inferred
       "module Public: {let value: int} = {let value = 1; let hidden = true}")
    (fun signature ->
      match signature with
      | [
       {
         psig_desc =
           Psig_module
             {
               pmd_name = { txt = "Public"; _ };
               pmd_type = { pmty_desc = Pmty_signature contents; _ };
               _;
             };
         _;
       };
      ] -> (
          match signature_value "value" contents with
          | Some value
            when Semantic_model.type_of Semantic_model.empty value.pval_type
                 = Int
                 && signature_value "hidden" contents = None ->
              Ok ()
          | _ -> Error "Constrained module signature was widened")
      | _ -> Error "Missing constrained module")

let nested_type =
  Result.bind (inferred "module Nested = {let value = [1, 2]}")
    (fun signature ->
      let scope = Semantic_model.signature Semantic_model.empty signature in
      match Semantic_model.resolve scope (Ldot (Lident "Nested", "value")) with
      | Some value when value.typ = Array Int -> Ok ()
      | _ -> Error "Nested inferred value type lost")

let exact_location =
  Result.bind (parse "// header\nlet visible = 1") (fun tree ->
      match Project_exports.declarations tree with
      | [ value ]
        when value.location.loc_start.pos_lnum = 2
             && value.location.loc_start.pos_cnum = 10
             && value.location.loc_end.pos_cnum = 25 ->
          Ok ()
      | [ value ] ->
          Error
            (Printf.sprintf
               "Expected declaration line 2, offsets 10..25; got line %d, \
                offsets %d..%d"
               value.location.loc_start.pos_lnum
               value.location.loc_start.pos_cnum value.location.loc_end.pos_cnum)
      | _ -> Error "Expected one exported declaration")

let opaque_metadata text predicate =
  Result.bind (inferred text) (fun signature ->
      if List.exists predicate signature then Ok ()
      else Error "Opaque export marker was lost")

let constrained_tuple_types =
  Result.bind (inferred "let (first, second): (int, bool) = (1, true)")
    (fun signature ->
      let types =
        List.filter_map
          (fun name ->
            Option.map
              (fun value ->
                Semantic_model.type_of Semantic_model.empty
                  value.Parsetree.pval_type)
              (signature_value name signature))
          [ "first"; "second" ]
      in
      if types = [ Semantic_model.Int; Bool ] then Ok ()
      else Error "Whole tuple annotation leaked onto each export")

let checks =
  [
    ( "simple declarations",
      exports [ [ "first" ]; [ "second" ] ] "let first = 1\nlet second = true"
    );
    ( "alias pattern",
      exports [ [ "whole" ]; [ "value" ] ] "let value as whole = input" );
    ("constrained pattern", exports [ [ "value" ] ] "let value: int = 1");
    ( "tuple pattern",
      exports [ [ "first" ]; [ "second" ] ] "let (first, second) = input" );
    ( "array pattern",
      exports [ [ "first" ]; [ "second" ] ] "let [first, second] = input" );
    ( "record pattern",
      exports [ [ "first" ]; [ "other" ] ] "let {first, second: other} = input"
    );
    ("wildcard pattern", exports [] "let _ = work()");
    ( "constructor payload binding",
      exports [ [ "value" ] ] "let Some(value) = input" );
    ( "external declaration",
      exports [ [ "call" ] ] "@val external call: int => unit = \"call\"" );
    ( "nested module exports",
      exports [ [ "Nested"; "value" ] ] "module Nested = {let value = 1}" );
    ( "recursive module exports",
      exports
        [ [ "Nested"; "value" ] ]
        "module rec Nested: {let value: int} = {let value = 1}" );
    ( "explicit module signature filters",
      exports
        [ [ "Nested"; "visible" ] ]
        "module Nested: {let visible: int} = {let visible = 1; let hidden = 2}"
    );
    ("opaque module aliases conservative", exports [] "module Nested = Other");
    ( "opaque named module constraint",
      exports [] "module Nested: Hidden = {let value = 1}" );
    ( "non-value declarations",
      exports [] "type value = int\nexception Missing\n()" );
    ( "signature values",
      exports ~kind:Source.Interface [ [ "value" ] ] "let value: int" );
    ( "signature nested values",
      exports ~kind:Source.Interface
        [ [ "Nested"; "value" ] ]
        "module Nested: {let value: int}" );
    ( "signature recursive modules",
      exports ~kind:Source.Interface
        [ [ "Nested"; "value" ] ]
        "module rec Nested: {let value: int}" );
    ( "signature opaque module types",
      exports ~kind:Source.Interface [] "module Nested: Hidden" );
    ( "signature unrelated declarations",
      exports ~kind:Source.Interface [] "type value = int\nexception Missing" );
    ( "public without interface",
      public_exports None
        [
          [ "visible" ];
          [ "hidden" ];
          [ "Nested"; "visible" ];
          [ "Nested"; "hidden" ];
        ] );
    ( "public follows interface",
      public_exports
        (Some "let visible: int\nmodule Nested: {let visible: bool}")
        [ [ "visible" ]; [ "Nested"; "visible" ] ] );
    ("empty interface hides everything", public_exports (Some "type t = int") []);
    ("inferred unit", inferred_type Unit "let value = ()");
    ("inferred bool", inferred_type Bool "let value = true");
    ("inferred int", inferred_type Int "let value = 1");
    ("inferred float", inferred_type Float "let value = 1.5");
    ("inferred string", inferred_type String "let value = \"text\"");
    ("inferred array", inferred_type (Array Int) "let value = [1, 2]");
    ( "inferred list",
      inferred_type (List Int) "let value = (unknown: list<int>)" );
    ("inferred option", inferred_type (Option Bool) "let value = Some(true)");
    ("inferred result", inferred_type (Result Int) "let value = Ok(1)");
    ( "inferred promise",
      inferred_type (Promise Int) "let value = (unknown: promise<int>)" );
    ( "inferred tuple",
      inferred_type (Tuple [ Int; Bool ]) "let value = (1, true)" );
    ( "inferred function",
      inferred_type
        (Function ([ (Nolabel, Int) ], Bool))
        "let value = (arg: int) => true" );
    ( "inferred async function",
      inferred_type
        (Function ([ (Nolabel, Int) ], Promise Bool))
        "let value = async (arg: int) => true" );
    ("unknown value stays unknown", inferred_type Unknown "let value = unknown");
    ( "structural record is not invented",
      inferred_type Unknown "let value = {field: 1}" );
    ("variant not invented", inferred_type Unknown "let value = #Ready");
    ("explicit annotations preserved", annotation_preserved);
    ("external FFI identity preserved", external_preserved);
    ("type declarations preserved", type_declaration_preserved);
    ("module signature preserved", constrained_module);
    ("nested inferred type", nested_type);
    ( "inferred recursive module",
      inferred_exports
        [ [ "Nested"; "value" ] ]
        "module rec Nested: {let value: int} = {let value = 1}" );
    ( "inferred opaque module alias omitted",
      inferred_exports [] "module Alias = Other" );
    ( "inferred non-value items omitted",
      inferred_exports [] "exception Missing\n()" );
    ( "inferred tuple exports",
      inferred_exports
        [ [ "first" ]; [ "second" ] ]
        "let (first, second) = (1, true)" );
    ( "inferred record exports",
      inferred_exports
        [ [ "first" ]; [ "second" ] ]
        "let {first, second} = record" );
    ( "inferred alias exports",
      inferred_exports [ [ "value" ]; [ "whole" ] ] "let value as whole = 1" );
    ("wildcard binding omitted", inferred_exports [] "let _ = work()");
    ("exact declaration location", exact_location);
    ( "variant payload binding",
      exports [ [ "value" ] ] "let #Value(value) = input" );
    ( "or-pattern bound name appears once",
      exports [ [ "value" ] ] "let (Some(value) | Some(value)) = input" );
    ("inline include exports", exports [ [ "value" ] ] "include {let value = 1}");
    ( "interface inline include exports",
      exports ~kind:Source.Interface [ [ "value" ] ] "include {let value: int}"
    );
    ( "inferred inline include exports",
      inferred_exports [ [ "value" ] ] "include {let value = 1}" );
    ( "inferred constructor export",
      inferred_exports [ [ "value" ] ] "let Some(value) = Some(1)" );
    ("destructured constraint types", constrained_tuple_types);
    ( "opaque module alias retained",
      opaque_metadata "module Vitest = Other"
        (fun (item : Parsetree.signature_item) ->
          match item.psig_desc with
          | Psig_module
              {
                pmd_name = { txt = "Vitest"; _ };
                pmd_type =
                  { pmty_desc = Pmty_alias { txt = Lident "Other"; _ }; _ };
                _;
              } ->
              true
          | _ -> false) );
    ( "opaque module application retained",
      opaque_metadata "module Vitest = Make(Other)"
        (fun (item : Parsetree.signature_item) ->
          match item.psig_desc with
          | Psig_module
              {
                pmd_name = { txt = "Vitest"; _ };
                pmd_type = { pmty_desc = Pmty_typeof _; _ };
                _;
              } ->
              true
          | _ -> false) );
    ( "opaque include retained",
      opaque_metadata "include Other" (fun (item : Parsetree.signature_item) ->
          match item.psig_desc with
          | Psig_include { pincl_mod = { pmty_desc = Pmty_typeof _; _ }; _ } ->
              true
          | _ -> false) );
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
