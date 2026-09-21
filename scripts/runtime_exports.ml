open Rescript_linter
module Names = Map.Make (String)
module Values = Set.Make (String)

type entry = string list * bool * string list

type shape = {
  values : Values.t;
  modules : shape Names.t;
  module_types : shape Names.t;
  opaque : bool;
}

let empty =
  {
    values = Values.empty;
    modules = Names.empty;
    module_types = Names.empty;
    opaque = false;
  }

let unknown = { empty with opaque = true }
let value name shape = { shape with values = Values.add name shape.values }

let module_ name nested shape =
  { shape with modules = Names.add name nested shape.modules }

let module_type_ name nested shape =
  { shape with module_types = Names.add name nested shape.module_types }

let overlay outer inner =
  let outer = if inner.opaque then empty else outer in
  let merge = Names.union (fun _ _ right -> Some right) in
  {
    values = Values.union outer.values inner.values;
    modules = merge outer.modules inner.modules;
    module_types = merge outer.module_types inner.module_types;
    opaque = outer.opaque || inner.opaque;
  }

let rec lookup select scope = function
  | Longident.Lident name -> Names.find_opt name (select scope)
  | Ldot (parent, name) ->
      Option.bind
        (lookup (fun shape -> shape.modules) scope parent)
        (fun shape -> Names.find_opt name (select shape))
  | Lapply _ -> None

let contents scope name =
  Option.value ~default:unknown (lookup (fun shape -> shape.modules) scope name)

let bound_values exports (binding : Parsetree.value_binding) =
  let bound =
    Semantic_model.bind_pattern Semantic_model.empty Unknown binding.pvb_pat
  in
  Semantic_model.Names.fold
    (fun name _ exports -> value name exports)
    bound.values exports

let add_scopes (scope, exports) (added, opened) =
  (overlay (overlay scope added) opened, overlay exports added)

let rec structure scope items =
  List.fold_left
    (fun ((scope, _) as scopes) item ->
      add_scopes scopes (structure_item scope item))
    (scope, empty) items
  |> snd

and structure_item scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_value (_, bindings) ->
      (List.fold_left bound_values empty bindings, empty)
  | Pstr_primitive declaration -> (value declaration.pval_name.txt empty, empty)
  | Pstr_module binding ->
      ( module_ binding.pmb_name.txt
          (module_expression scope binding.pmb_expr)
          empty,
        empty )
  | Pstr_include inclusion ->
      (module_expression scope inclusion.pincl_mod, empty)
  | _ -> structure_other scope item

and structure_other scope (item : Parsetree.structure_item) =
  match item.pstr_desc with
  | Pstr_modtype declaration ->
      (module_type_declaration scope declaration, empty)
  | Pstr_open opening -> (empty, contents scope opening.popen_lid.txt)
  | Pstr_recmodule bindings ->
      ( List.fold_left
          (fun exports binding ->
            module_ binding.Parsetree.pmb_name.txt unknown exports)
          empty bindings,
        empty )
  | Pstr_extension _ -> (unknown, empty)
  | _ -> (empty, empty)

and signature scope items =
  List.fold_left
    (fun ((scope, _) as scopes) item ->
      add_scopes scopes (signature_item scope item))
    (scope, empty) items
  |> snd

and signature_item scope (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value declaration -> (value declaration.pval_name.txt empty, empty)
  | Psig_module declaration ->
      ( module_ declaration.pmd_name.txt
          (module_type scope declaration.pmd_type)
          empty,
        empty )
  | Psig_include inclusion -> (module_type scope inclusion.pincl_mod, empty)
  | Psig_modtype declaration ->
      (module_type_declaration scope declaration, empty)
  | _ -> signature_other scope item

and signature_other scope (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_open opening -> (empty, contents scope opening.popen_lid.txt)
  | Psig_recmodule declarations ->
      ( List.fold_left
          (fun exports declaration ->
            module_ declaration.Parsetree.pmd_name.txt unknown exports)
          empty declarations,
        empty )
  | Psig_extension _ -> (unknown, empty)
  | _ -> (empty, empty)

and module_expression scope (node : Parsetree.module_expr) =
  match node.pmod_desc with
  | Pmod_structure items -> structure scope items
  | Pmod_ident name -> contents scope name.txt
  | Pmod_constraint (_, typ) -> module_type scope typ
  | _ -> unknown

and module_type scope (node : Parsetree.module_type) =
  match node.pmty_desc with
  | Pmty_signature items -> signature scope items
  | Pmty_alias name -> contents scope name.txt
  | Pmty_ident name ->
      Option.value ~default:unknown
        (lookup (fun shape -> shape.module_types) scope name.txt)
  | Pmty_typeof expression -> module_expression scope expression
  | _ -> unknown

and module_type_declaration scope
    (declaration : Parsetree.module_type_declaration) =
  let shape =
    Option.fold ~none:unknown ~some:(module_type scope) declaration.pmtd_type
  in
  module_type_ declaration.pmtd_name.txt shape empty

let tree_exports scope = function
  | Parser.Implementation items -> structure scope items
  | Interface items -> signature scope items

let resolve units =
  let initial =
    List.fold_left
      (fun scope (name, _) -> module_ name unknown scope)
      empty units
  in
  let rec round remaining previous =
    if remaining = 0 then previous
    else
      let next =
        List.fold_left
          (fun scope (name, tree) ->
            module_ name (tree_exports previous tree) scope)
          empty units
      in
      if next = previous then next else round (remaining - 1) next
  in
  round (List.length units + 1) initial

let rec flatten path shape =
  (path, shape.opaque, Values.elements shape.values)
  :: (Names.bindings shape.modules
     |> List.concat_map (fun (name, nested) -> flatten (path @ [ name ]) nested)
     )

let entries units =
  Names.bindings (resolve units).modules
  |> List.concat_map (fun (name, shape) -> flatten [ name ] shape)

let io filename run =
  try Ok (run ()) with
  | Sys_error detail -> Error (Lint_error.Read_error { filename; detail })
  | Unix.Unix_error (error, operation, _) ->
      Error
        (Lint_error.Read_error
           { filename; detail = operation ^ ": " ^ Unix.error_message error })

let choose_file files filename =
  let name = Filename.remove_extension filename |> String.capitalize_ascii in
  match (Filename.extension filename, Names.find_opt name files) with
  | ".resi", _ | ".res", None -> Names.add name filename files
  | _ -> files

let read_unit directory (name, filename) =
  let filename = Filename.concat directory filename in
  Result.bind (Source.read filename) (fun source ->
      Result.map (fun tree -> (name, tree)) (Parser.parse source))

let read ~directory =
  Result.bind
    (io directory (fun () -> Sys.readdir directory))
    (fun files ->
      let selected =
        Array.fold_left choose_file Names.empty files |> Names.bindings
      in
      List.fold_left
        (fun result file ->
          Result.bind result (fun units ->
              Result.map (fun unit -> unit :: units) (read_unit directory file)))
        (Ok []) selected
      |> Result.map entries)

let strings names =
  "[" ^ String.concat "; " (List.map (Printf.sprintf "%S") names) ^ "]"

let render entries =
  let row (path, opaque, values) =
    Printf.sprintf "  (%s, %b, %s);\n" (strings path) opaque (strings values)
  in
  "(* Generated by scripts/generate_banned_runtime.ml from the pinned runtime. \
   *)\n" ^ "let modules : (string list * bool * string list) list = [\n"
  ^ String.concat "" (List.map row entries)
  ^ "]\n"
