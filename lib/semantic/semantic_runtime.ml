open Semantic_model

let operators =
  [
    "+";
    "-";
    "*";
    "/";
    "mod";
    "+.";
    "-.";
    "*.";
    "/.";
    "++";
    "==";
    "!=";
    "===";
    "!==";
    "<";
    ">";
    "<=";
    ">=";
    "&&";
    "||";
    "not";
    "->";
  ]

let add_builtin module_name scope (member, arity, result, pure) =
  let api = [ module_name; member ] in
  add_value member
    {
      identity = "runtime:" ^ String.concat "." api;
      typ =
        Function (List.init arity (fun _ -> (Asttypes.Nolabel, Unknown)), result);
      api = Some api;
      pure;
      expression = None;
      attributes = [];
      canonical = Some api;
      declaration_origin = External;
    }
    scope

let module_bindings =
  [
    ( "Array",
      [
        ("length", 1, Int, true);
        ("isEmpty", 1, Bool, true);
        ("make", 2, Array Unknown, true);
        ("fromInitializer", 2, Array Unknown, false);
        ("get", 2, Option Unknown, true);
        ("getUnsafe", 2, Unknown, true);
        ("map", 2, Array Unknown, false);
        ("filter", 2, Array Unknown, false);
        ("flatMap", 2, Array Unknown, false);
        ("reduce", 3, Unknown, false);
        ("concat", 2, Array Unknown, true);
        ("join", 2, String, true);
      ] );
    ( "List",
      [
        ("length", 1, Int, true);
        ("head", 1, Option Unknown, true);
        ("tail", 1, Option (List Unknown), true);
        ("get", 2, Option Unknown, true);
        ("headExn", 1, Unknown, false);
        ("headOrThrow", 1, Unknown, false);
        ("tailExn", 1, List Unknown, false);
        ("tailOrThrow", 1, List Unknown, false);
        ("getExn", 2, Unknown, false);
        ("getOrThrow", 2, Unknown, false);
        ("map", 2, List Unknown, false);
        ("filter", 2, List Unknown, false);
        ("filterMap", 2, List Unknown, false);
        ("reduce", 3, Unknown, false);
        ("concat", 2, List Unknown, true);
      ] );
    ( "String",
      [
        ("length", 1, Int, true);
        ("isEmpty", 1, Bool, true);
        ("get", 2, Option String, true);
        ("getUnsafe", 2, String, true);
      ] );
    ( "Option",
      [
        ("getExn", 1, Unknown, false);
        ("getOrThrow", 1, Unknown, false);
        ("getUnsafe", 1, Unknown, true);
        ("ignore", 1, Unit, true);
      ] );
    ( "Result",
      [
        ("getExn", 1, Unknown, false);
        ("getOrThrow", 1, Unknown, false);
        ("ignore", 1, Unit, true);
      ] );
    ( "Promise",
      [
        ("resolve", 1, Promise Unknown, false);
        ("reject", 1, Promise Unknown, false);
        ("make", 1, Promise Unknown, false);
        ("then", 2, Promise Unknown, false);
        ("thenResolve", 2, Promise Unknown, false);
        ("all", 1, Promise (Array Unknown), false);
        ("ignore", 1, Unit, true);
      ] );
    ( "Int",
      [ ("fromString", 1, Option Int, true); ("toString", 1, String, true) ] );
    ( "Console",
      [
        ("log", 1, Unit, false);
        ("info", 1, Unit, false);
        ("warn", 1, Unit, false);
        ("error", 1, Unit, false);
      ] );
    ("Dict", []);
  ]

let module_scope (name, functions) =
  List.fold_left (add_builtin name)
    { empty with origin = Some [ name ] }
    functions

let runtime =
  let scope =
    List.fold_left
      (fun scope ((name, _) as definition) ->
        let nested = module_scope definition in
        add_module ("Stdlib_" ^ name) nested (add_module name nested scope))
      empty module_bindings
  in
  let scope =
    List.fold_left
      (fun scope name ->
        add_builtin "Stdlib" scope
          ( name,
            2,
            Unknown,
            not (List.mem name [ "/"; "mod"; "=="; "!="; "<"; "<="; ">"; ">=" ])
          ))
      scope operators
  in
  let scope = add_builtin "Stdlib" scope ("ignore", 1, Unit, true) in
  let scope =
    add_constructor "None" (Option Unknown)
      (add_constructor "Some" (Option Unknown) scope)
  in
  let scope =
    add_constructor "Ok" (Result Unknown)
      (add_constructor "Error" (Result Unknown) scope)
  in
  add_module "Stdlib" scope scope

let add_runtime_types scope =
  List.fold_left
    (fun scope (name, typ) ->
      match Names.find_opt name scope.modules with
      | None -> scope
      | Some nested ->
          let nested = add_type ~standard:true "t" typ nested in
          add_module ("Stdlib_" ^ name) nested (add_module name nested scope))
    scope
    [
      ("Array", Array Unknown);
      ("List", List Unknown);
      ("String", String);
      ("Option", Option Unknown);
      ("Result", Result Unknown);
      ("Promise", Promise Unknown);
      ("Int", Int);
      ("Dict", Unknown);
    ]

let rec signature_size items =
  List.fold_left
    (fun size (item : Parsetree.signature_item) ->
      size + 1
      +
      match item.psig_desc with
      | Psig_module declaration -> module_type_size declaration.pmd_type
      | Psig_include inclusion -> module_type_size inclusion.pincl_mod
      | _ -> 0)
    0 items

and module_type_size (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> signature_size items
  | _ -> 0

let namespace_scope context name scope =
  if not (List.mem name context.namespace_roots) then scope
  else
    match Names.find_opt name scope.modules with
    | Some nested when not nested.opaque -> overlay scope nested
    | Some _ | None -> scope

let initial_scope context =
  let runtime = add_runtime_types runtime in
  let runtime = add_module "Stdlib" runtime runtime in
  let scope =
    List.fold_left
      (fun scope name -> add_module name unknown scope)
      runtime context.project_modules
  in
  let populate scope =
    List.fold_left
      (fun scope (name, items) ->
        add_module name
          (signature ~prefix:[ name ] ~value_origins:context.value_origins
             ~type_origins:context.type_origins
             (namespace_scope context name scope)
             items)
          scope)
      scope context.module_signatures
  in
  let rec settle remaining scope =
    if remaining = 0 then scope
    else
      let next = populate scope in
      if next = scope then next else settle (remaining - 1) next
  in
  let limit =
    List.fold_left
      (fun limit (_, items) -> limit + 1 + signature_size items)
      1 context.module_signatures
  in
  settle limit scope
