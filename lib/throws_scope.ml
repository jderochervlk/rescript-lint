module Names = Map.Make (String)

type exception_ref = { identity : string; display : string }
type contract = Any | Named of exception_ref list
type callable = Plain | Annotated of contract
type error = Unresolved_exception of string list

type t = {
  values : callable Names.t;
  exceptions : string option Names.t;
  modules : t Names.t;
  identities : string Names.t;
  opaque : bool;
}

let empty =
  {
    values = Names.empty;
    exceptions = Names.empty;
    modules = Names.empty;
    identities = Names.empty;
    opaque = false;
  }

let unknown = { empty with opaque = true }
let is_opaque scope = scope.opaque

let add_value name value scope =
  { scope with values = Names.add name value scope.values }

let add_module name value scope =
  { scope with modules = Names.add name value scope.modules }

let add_exception name value scope =
  { scope with exceptions = Names.add name value scope.exceptions }

let initial =
  List.fold_left
    (fun scope name -> add_exception name (Some ("builtin:" ^ name)) scope)
    empty
    [
      "Not_found";
      "Invalid_argument";
      "Failure";
      "JsExn";
      "End_of_file";
      "Division_by_zero";
      "Match_failure";
      "Assert_failure";
      "Undefined_recursive_module";
    ]

let overlay outer inner =
  let merge left right = Names.union (fun _ _ right -> Some right) left right in
  let outer =
    if inner.opaque then { empty with identities = outer.identities } else outer
  in
  {
    values = merge outer.values inner.values;
    exceptions = merge outer.exceptions inner.exceptions;
    modules = merge outer.modules inner.modules;
    identities = merge outer.identities inner.identities;
    opaque = outer.opaque || inner.opaque;
  }

let rec module_scope scope = function
  | [] -> Some scope
  | name :: rest ->
      Option.bind (Names.find_opt name scope.modules) (fun scope ->
          module_scope scope rest)

let rec lookup select scope = function
  | [] -> None
  | [ name ] -> Names.find_opt name (select scope)
  | name :: rest ->
      Option.bind (Names.find_opt name scope.modules) (fun scope ->
          lookup select scope rest)

let value = lookup (fun scope -> scope.values)

let exception_id scope names =
  Option.join (lookup (fun scope -> scope.exceptions) scope names)

let rec bind_pattern value (pattern : Parsetree.pattern) scope =
  match pattern.ppat_desc with
  | Ppat_var name -> add_value name.txt value scope
  | Ppat_alias (inner, name) ->
      add_value name.txt value (bind_pattern value inner scope)
  | Ppat_constraint (inner, _) -> bind_pattern value inner scope
  | _ -> bind_children value pattern scope

and bind_children value pattern scope =
  (* The compiler visitor returns unit; keep pattern-name collection local. *)
  let result = ref scope in
  let visitor =
    {
      Ast_iterator.default_iterator with
      pat = (fun _ child -> result := bind_pattern value child !result);
      attributes = (fun _ _ -> ());
    }
  in
  (match pattern.ppat_desc with
  | Ppat_unpack name -> result := add_module name.txt empty scope
  | _ -> Ast_iterator.default_iterator.pat visitor pattern);
  !result

let exception_export ~filename scope
    (declaration : Parsetree.extension_constructor) =
  let identity =
    match declaration.pext_kind with
    | Pext_decl _ ->
        Some
          (filename ^ ":"
          ^ string_of_int declaration.pext_loc.loc_start.pos_cnum)
    | Pext_rebind name ->
        Option.bind (Throws_annotation.path name.txt) (exception_id scope)
  in
  let identity =
    Option.map
      (fun identity ->
        Option.value ~default:identity
          (Names.find_opt identity scope.identities))
      identity
  in
  add_exception declaration.pext_name.txt identity empty

let bind_exception ~filename declaration scope =
  overlay scope (exception_export ~filename scope declaration)

let shadow_types declarations scope =
  List.fold_left
    (fun scope (declaration : Parsetree.type_declaration) ->
      match declaration.ptype_kind with
      | Ptype_variant constructors ->
          List.fold_left
            (fun scope (constructor : Parsetree.constructor_declaration) ->
              add_exception constructor.pcd_name.txt None scope)
            scope constructors
      | _ -> scope)
    scope declarations

let resolve scope = function
  | Throws_annotation.Any -> Ok Any
  | Named names ->
      let add result name =
        Result.bind result (fun references ->
            let display = String.concat "." name in
            match exception_id scope name with
            | Some identity -> Ok ({ identity; display } :: references)
            | None -> Error (Unresolved_exception name))
      in
      Result.map
        (fun references -> Named (List.rev references))
        (List.fold_left add (Ok []) names)

let rec exception_bindings scope =
  List.filter_map
    (fun (name, identity) ->
      Option.map (fun identity -> ([ name ], identity)) identity)
    (Names.bindings scope.exceptions)
  @ List.concat_map
      (fun (name, nested) ->
        List.map
          (fun (path, identity) -> (name :: path, identity))
          (exception_bindings nested))
      (Names.bindings scope.modules)

let with_exception_aliases aliases scope =
  let identities =
    List.fold_left
      (fun mapping (from, target) -> Names.add from target mapping)
      scope.identities aliases
  in
  let identity original =
    Option.value ~default:original (Names.find_opt original identities)
  in
  let callable = function
    | Annotated (Named exceptions) ->
        Annotated
          (Named
             (List.map
                (fun exception_ ->
                  { exception_ with identity = identity exception_.identity })
                exceptions))
    | callable -> callable
  in
  let rec remap scope =
    {
      values = Names.map callable scope.values;
      exceptions = Names.map (Option.map identity) scope.exceptions;
      modules = Names.map remap scope.modules;
      identities;
      opaque = scope.opaque;
    }
  in
  remap scope

let exception_aliases scope = Names.bindings scope.identities
