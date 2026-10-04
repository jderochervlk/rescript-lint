open Rescript_linter

let expect name value = (name, value)
let unresolved_path = Longident.Ldot (Lapply (Lident "F", Lident "X"), "Error")

let malformed_constructor =
  let expression =
    Ast_helper.Exp.construct (Location.mknoloc unresolved_path) None
  in
  let attribute =
    ( Location.mknoloc "throws",
      Parsetree.PStr [ Ast_helper.Str.eval expression ] )
  in
  match Throws_annotation.decode [ attribute ] with
  | Error _ -> true
  | Ok _ -> false

let unpack_shadow =
  let scope =
    Throws_scope.add_module "Api"
      (Throws_scope.add_value "read" Plain Throws_scope.empty)
      Throws_scope.initial
  in
  let pattern =
    {
      (Ast_helper.Pat.any ()) with
      Parsetree.ppat_desc = Ppat_unpack (Location.mknoloc "Api");
    }
  in
  let shadowed = Throws_scope.bind_pattern Plain pattern scope in
  Throws_scope.value scope [ "Api"; "read" ] = Some Plain
  && Throws_scope.value shadowed [ "Api"; "read" ] = None

let unsupported_functor_reference =
  let source =
    Source.
      {
        filename = "model.res";
        kind = Implementation;
        text = "@throws(Not_found)\nlet read = () => 0";
      }
  in
  match Parser.parse source with
  | Ok (Implementation items) -> (
      let expression =
        Ast_helper.Exp.ident (Location.mknoloc unresolved_path)
      in
      match
        No_unhandled_throws.check ~source
          (Implementation (items @ [ Ast_helper.Str.eval expression ]))
      with
      | Error (Lint_error.Analysis_errors _) -> true
      | _ -> false)
  | _ -> false

let opaque_scope =
  let known =
    Throws_scope.add_value "read" Plain
      (Throws_scope.add_module "Api" Throws_scope.empty Throws_scope.initial)
  in
  let hidden = Throws_scope.overlay known Throws_scope.unknown in
  let remapped = Throws_scope.with_exception_aliases [] hidden in
  Throws_scope.is_opaque remapped
  && (not (Throws_scope.is_opaque known))
  && Throws_scope.value remapped [ "read" ] = None
  && Throws_scope.module_scope remapped [ "Api" ] = None
  && Throws_scope.exception_id remapped [ "Not_found" ] = None

let checks =
  [
    expect "unresolved functor constructor" malformed_constructor;
    expect "empty value path" (Throws_scope.value Throws_scope.initial [] = None);
    expect "unpacked module shadows previous module" unpack_shadow;
    expect "unresolved functor values fail analysis"
      unsupported_functor_reference;
    expect "opaque exports invalidate inherited declarations" opaque_scope;
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
