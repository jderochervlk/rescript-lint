module Names = Map.Make (String)

type typ =
  | Unknown
  | Unit
  | Bool
  | Int
  | Float
  | String
  | Array of typ
  | List of typ
  | Option of typ
  | Result of typ
  | Promise of typ
  | Tuple of typ list
  | Record of (string * typ * bool) list
  | Variant of bool
  | Regexp
  | Function of (Asttypes.arg_label * typ) list * typ

type value = {
  identity : string;
  typ : typ;
  api : string list option;
  pure : bool;
  expression : Parsetree.expression option;
  attributes : Parsetree.attributes;
  canonical : string list option;
}

type type_origin = Standard of string list | Declared of string list option

type scope = {
  values : value Names.t;
  modules : scope Names.t;
  types : typ Names.t;
  type_identities : type_origin Names.t;
  constructors : typ Names.t;
  origin : string list option;
  opaque : bool;
}

type context = {
  module_signatures : (string * Parsetree.signature) list;
  project_modules : string list;
  entry_module : bool;
  deep_equality_threshold : int;
  enabled : string list;
}

let default_context =
  {
    module_signatures = [];
    project_modules = [];
    entry_module = false;
    deep_equality_threshold = 4;
    enabled = [];
  }

let empty =
  {
    values = Names.empty;
    modules = Names.empty;
    types = Names.empty;
    type_identities = Names.empty;
    constructors = Names.empty;
    origin = None;
    opaque = false;
  }

let unknown = { empty with opaque = true }

let add_value name value scope =
  { scope with values = Names.add name value scope.values }

let add_module name value scope =
  { scope with modules = Names.add name value scope.modules }

let add_type ?(standard = false) name value scope =
  let path = Option.map (fun path -> path @ [ name ]) scope.origin in
  let origin =
    match (standard, path) with
    | true, Some path -> Standard path
    | _ -> Declared path
  in
  {
    scope with
    types = Names.add name value scope.types;
    type_identities = Names.add name origin scope.type_identities;
  }

let add_constructor name value scope =
  { scope with constructors = Names.add name value scope.constructors }

let overlay outer inner =
  let merge outer inner =
    Names.union (fun _ _ right -> Some right) outer inner
  in
  let outer =
    if inner.opaque then { empty with origin = outer.origin } else outer
  in
  {
    values = merge outer.values inner.values;
    modules = merge outer.modules inner.modules;
    types = merge outer.types inner.types;
    type_identities = merge outer.type_identities inner.type_identities;
    constructors = merge outer.constructors inner.constructors;
    origin = outer.origin;
    opaque = outer.opaque || inner.opaque;
  }

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let rec lookup select scope = function
  | [] -> None
  | [ name ] -> Names.find_opt name (select scope)
  | name :: rest ->
      Option.bind (Names.find_opt name scope.modules) (fun nested ->
          lookup select nested rest)

let rec module_path scope = function
  | [] -> Some scope
  | name :: rest ->
      Option.bind (Names.find_opt name scope.modules) (fun nested ->
          module_path nested rest)

let resolve scope identifier =
  Option.bind (path identifier) (lookup (fun scope -> scope.values) scope)

let module_identity scope identifier =
  Option.bind
    (Option.bind (path identifier) (module_path scope))
    (fun nested -> nested.origin)

let type_identity scope identifier =
  Option.bind
    (Option.bind (path identifier)
       (lookup (fun scope -> scope.type_identities) scope))
    (function Standard path -> Some path | Declared path -> path)

let standard_type scope identifier =
  Option.bind
    (Option.bind (path identifier)
       (lookup (fun scope -> scope.type_identities) scope))
    (function Standard path -> Some path | Declared _ -> None)

let open_path scope identifier =
  match Option.bind (path identifier) (module_path scope) with
  | Some nested -> overlay scope nested
  | None -> unknown

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) -> unwrap inner
  | _ -> expression

let rec type_of scope (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_constr (name, arguments) -> named_type scope name.txt arguments
  | Ptyp_tuple items -> Tuple (List.map (type_of scope) items)
  | Ptyp_arrow { arity; _ } ->
      let args, result = arrow_type scope (Option.value ~default:1 arity) typ in
      Function (args, result)
  | Ptyp_alias (inner, _) | Ptyp_poly (_, inner) -> type_of scope inner
  | Ptyp_object _ -> Record []
  | Ptyp_variant (fields, _, _) ->
      Variant
        (List.exists
           (function
             | Parsetree.Rtag (_, _, _, args) -> args <> [] | Rinherit _ -> true)
           fields)
  | _ -> Unknown

and arrow_type scope remaining (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_arrow { arg; ret; _ } when remaining > 0 ->
      let args, result = arrow_type scope (remaining - 1) ret in
      ((arg.lbl, type_of scope arg.typ) :: args, result)
  | _ -> ([], type_of scope typ)

and named_type scope identifier arguments =
  let argument =
    match arguments with first :: _ -> type_of scope first | [] -> Unknown
  in
  match path identifier with
  | Some [ "unit" ] -> Unit
  | Some [ "bool" ] -> Bool
  | Some [ "int" ] -> Int
  | Some [ "float" ] -> Float
  | Some [ "string" ] -> String
  | Some [ "array" ] -> Array argument
  | Some [ "list" ] -> List argument
  | Some [ "option" ] -> Option argument
  | Some [ "result" ] -> Result argument
  | Some [ "promise" ] -> Promise argument
  | Some names ->
      Option.value ~default:Unknown
        (lookup (fun scope -> scope.types) scope names)
  | None -> Unknown

let identity (location : Location.t) =
  location.loc_start.pos_fname ^ ":" ^ string_of_int location.loc_start.pos_cnum

let unknown_value location =
  {
    identity = identity location;
    typ = Unknown;
    api = None;
    pure = false;
    expression = None;
    attributes = [];
    canonical = None;
  }

let rec bind_pattern scope typ (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name ->
      add_value name.txt { (unknown_value pattern.ppat_loc) with typ } scope
  | Ppat_alias (inner, name) ->
      add_value name.txt
        { (unknown_value name.loc) with typ }
        (bind_pattern scope typ inner)
  | Ppat_constraint (inner, annotation) ->
      bind_pattern scope (type_of scope annotation) inner
  | Ppat_tuple patterns ->
      let types =
        match typ with
        | Tuple types when List.length types = List.length patterns -> types
        | _ -> List.map (fun _ -> Unknown) patterns
      in
      List.fold_left2 bind_pattern scope types patterns
  | Ppat_unpack name -> add_module name.txt unknown scope
  | Ppat_construct ({ txt = Lident "Some"; _ }, Some inner) ->
      let typ = match typ with Option value -> value | _ -> Unknown in
      bind_pattern scope typ inner
  | Ppat_construct ({ txt = Lident "Ok"; _ }, Some inner) ->
      let typ = match typ with Result value -> value | _ -> Unknown in
      bind_pattern scope typ inner
  | Ppat_construct ({ txt = Lident "::"; _ }, Some inner) ->
      let item = match typ with List item -> item | _ -> Unknown in
      bind_pattern scope (Tuple [ item; List item ]) inner
  | _ -> bind_pattern_children scope pattern

and bind_pattern_children scope pattern =
  let result = ref scope in
  let default = Ast_iterator.default_iterator in
  let visitor =
    {
      default with
      pat = (fun _ child -> result := bind_pattern !result Unknown child);
      attribute = (fun _ _ -> ());
      attributes = (fun _ _ -> ());
    }
  in
  default.pat visitor pattern;
  !result

let rec pattern_name (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_var name -> Some name.txt
  | Ppat_constraint (inner, _) -> pattern_name inner
  | _ -> None

let rec pattern_type scope (pattern : Parsetree.pattern) =
  match pattern.ppat_desc with
  | Ppat_constraint (_, typ) -> type_of scope typ
  | Ppat_alias (inner, _) -> pattern_type scope inner
  | _ -> Unknown

let function_parts expression =
  let rec parameters remaining expression =
    match (unwrap expression).pexp_desc with
    | Pexp_fun { arg_label; lhs; rhs; _ } when remaining > 0 ->
        let rest, body = parameters (remaining - 1) rhs in
        ((arg_label, lhs) :: rest, body)
    | _ -> ([], expression)
  in
  match (unwrap expression).pexp_desc with
  | Pexp_fun { arity; _ } ->
      parameters (Option.value ~default:1 arity) expression
  | _ -> ([], expression)

let has_attribute name attributes =
  List.exists (fun ((id : string Location.loc), _) -> id.txt = name) attributes

let application scope expression =
  let direct expression =
    match (unwrap expression).pexp_desc with
    | Pexp_apply { funct; args; partial = false; _ } -> Some (funct, args)
    | _ -> None
  in
  match direct expression with
  | Some ({ pexp_desc = Pexp_ident name; _ }, [ (_, value); (_, target) ])
    when Option.bind (resolve scope name.txt) (fun value -> value.api)
         = Some [ "Stdlib"; "->" ] -> (
      match direct target with
      | Some (funct, arguments) ->
          Some (funct, (Asttypes.Nolabel, value) :: arguments)
      | None -> (
          match (unwrap target).pexp_desc with
          | Pexp_ident _ -> Some (target, [ (Asttypes.Nolabel, value) ])
          | _ -> None))
  | result -> result

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

let rec infer scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (_, typ) -> type_of scope typ
  | Pexp_ident name ->
      Option.fold ~none:Unknown
        ~some:(fun value -> value.typ)
        (resolve scope name.txt)
  | Pexp_constant constant -> constant_type constant
  | Pexp_array values -> Array (first_type scope values)
  | Pexp_tuple values -> Tuple (List.map (infer scope) values)
  | Pexp_record (fields, _) -> record_type scope fields
  | Pexp_construct (name, argument) -> constructor_type scope name.txt argument
  | Pexp_variant (_, argument) -> Variant (argument <> None)
  | Pexp_fun { async; _ } -> function_type scope async expression
  | Pexp_apply _ ->
      Option.fold ~none:Unknown
        ~some:(fun (funct, args) -> call_type scope funct args)
        (application scope expression)
  | Pexp_await value -> (
      match infer scope value with Promise typ -> typ | _ -> Unknown)
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "true"; _ }, None); _ },
        yes,
        _ ) ->
      infer scope yes
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "false"; _ }, None); _ },
        _,
        no ) ->
      Option.fold ~none:Unit ~some:(infer scope) no
  | Pexp_ifthenelse (_, yes, Some no) ->
      let typ = infer scope yes in
      if typ = infer scope no then typ else Unknown
  | Pexp_sequence (_, last) -> infer scope last
  | Pexp_let (_, bindings, body) ->
      let nested =
        List.fold_left
          (fun scope (binding : Parsetree.value_binding) ->
            let typ =
              match pattern_type scope binding.pvb_pat with
              | Unknown -> infer scope binding.pvb_expr
              | typ -> typ
            in
            bind_pattern scope typ binding.pvb_pat)
          scope bindings
      in
      infer nested body
  | Pexp_match (value, cases) -> (
      let value_type = infer scope value in
      let types =
        List.map
          (fun (case : Parsetree.case) ->
            infer (bind_pattern scope value_type case.pc_lhs) case.pc_rhs)
          cases
      in
      match List.sort_uniq compare types with [ typ ] -> typ | _ -> Unknown)
  | Pexp_field (record, field) -> field_type (infer scope record) field.txt
  | _ -> Unknown

and constant_type = function
  | Parsetree.Pconst_integer (_, None) -> Int
  | Pconst_float (_, None) -> Float
  | Pconst_string (_, None) -> String
  | _ -> Unknown

and first_type scope = function
  | first :: _ -> infer scope first
  | [] -> Unknown

and record_type scope fields =
  let names =
    List.filter_map
      (fun field ->
        match path field.Parsetree.lid.txt with
        | Some [ name ] -> Some name
        | _ -> None)
      fields
  in
  let declared =
    Names.bindings scope.types
    |> List.filter_map (fun (_, typ) ->
        match typ with
        | Record known
          when List.sort compare names
               = List.sort compare (List.map (fun (name, _, _) -> name) known)
          ->
            Some typ
        | _ -> None)
  in
  match List.sort_uniq compare declared with
  | [ typ ] -> typ
  | _ -> Record (List.map (fun name -> (name, Unknown, false)) names)

and constructor_type scope identifier argument =
  let item = Option.fold ~none:Unknown ~some:(infer scope) argument in
  match path identifier with
  | Some [ "()" ] -> Unit
  | Some [ "true" ] | Some [ "false" ] -> Bool
  | Some [ "[]" ] -> List Unknown
  | Some [ "::" ] -> List Unknown
  | Some [ "Some" ]
    when Names.find_opt "Some" scope.constructors = Some (Option Unknown) ->
      Option item
  | Some [ "Ok" ]
    when Names.find_opt "Ok" scope.constructors = Some (Result Unknown) ->
      Result item
  | Some names ->
      Option.value ~default:Unknown
        (lookup (fun scope -> scope.constructors) scope names)
  | None -> Unknown

and function_type scope async expression =
  let parameters, body = function_parts expression in
  let parameters =
    List.map
      (fun (label, pattern) -> (label, pattern_type scope pattern, pattern))
      parameters
  in
  let nested =
    List.fold_left
      (fun scope (_, typ, pattern) -> bind_pattern scope typ pattern)
      scope parameters
  in
  let result = infer nested body in
  Function
    ( List.map (fun (label, typ, _) -> (label, typ)) parameters,
      if async then Promise result else result )

and field_type typ identifier =
  match (typ, path identifier) with
  | Record fields, Some [ name ] ->
      Option.fold ~none:Unknown
        ~some:(fun (_, typ, _) -> typ)
        (List.find_opt (fun (field, _, _) -> field = name) fields)
  | _ -> Unknown

and call_type scope funct arguments =
  match (unwrap funct).pexp_desc with
  | Pexp_ident name -> (
      match resolve scope name.txt with
      | Some { api = Some api; typ = Function (parameters, _) as typ; _ }
        when List.length parameters = List.length arguments -> (
          match (api_result scope api arguments, typ) with
          | Unknown, Function (parameters, result)
            when List.length parameters = List.length arguments ->
              result
          | inferred, _ -> inferred)
      | Some { typ = Function (parameters, result); _ }
        when List.length parameters = List.length arguments ->
          result
      | _ -> Unknown)
  | _ -> (
      match infer scope funct with
      | Function (parameters, result)
        when List.length parameters = List.length arguments ->
          result
      | _ -> Unknown)

and api_result scope api arguments =
  let first =
    match arguments with (_, value) :: _ -> infer scope value | [] -> Unknown
  in
  match api with
  | [ "Array"; "make" ]
  | [ "Array"; "fromInitializer" ]
  | [ "Array"; "map" ]
  | [ "Array"; "filter" ]
  | [ "Array"; "flatMap" ]
  | [ "Array"; "concat" ] ->
      Array Unknown
  | [ "List"; "map" ] | [ "List"; "filter" ] | [ "List"; "concat" ] ->
      List Unknown
  | [ "Promise"; "resolve" ] -> (
      match first with Promise _ -> first | typ -> Promise typ)
  | [ "Promise"; _ ] when api <> [ "Promise"; "ignore" ] -> Promise Unknown
  | [ "Int"; "fromString" ] -> Option Int
  | [ _; "length" ] -> Int
  | [ _; "isEmpty" ] -> Bool
  | [ "Array"; "get" ] -> (
      match first with Array typ -> Option typ | _ -> Option Unknown)
  | [ "List"; "head" ] -> (
      match first with List typ -> Option typ | _ -> Option Unknown)
  | [ "Array"; "getUnsafe" ] -> (
      match first with Array typ -> typ | _ -> Unknown)
  | [ "Stdlib"; "ignore" ] | [ _; "ignore" ] | [ "Console"; _ ] -> Unit
  | [ "Stdlib"; operator ] when List.mem operator [ "+."; "-."; "*."; "/." ] ->
      Float
  | [ "Stdlib"; operator ] when List.mem operator [ "+"; "-"; "*"; "/"; "mod" ]
    ->
      Int
  | [ "Stdlib"; "++" ] -> String
  | [ "Stdlib"; _ ] -> Bool
  | _ -> Unknown

let rec pure scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident _ | Pexp_constant _ | Pexp_fun _ -> true
  | Pexp_construct (_, value) | Pexp_variant (_, value) ->
      Option.fold ~none:true ~some:(pure scope) value
  | Pexp_tuple values | Pexp_array values -> List.for_all (pure scope) values
  | Pexp_apply _ ->
      Option.fold ~none:false
        ~some:(fun (funct, args) ->
          callable_pure scope funct
          && List.for_all (fun (_, arg) -> pure scope arg) args)
        (application scope expression)
  | Pexp_ifthenelse (condition, yes, no) ->
      pure scope condition && pure scope yes
      && Option.fold ~none:true ~some:(pure scope) no
  | _ -> false

and callable_pure scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name ->
      Option.fold ~none:false
        ~some:(fun value -> value.pure)
        (resolve scope name.txt)
  | Pexp_fun _ ->
      let parameters, body = function_parts expression in
      let nested =
        List.fold_left
          (fun scope (_, pattern) ->
            bind_pattern scope (pattern_type scope pattern) pattern)
          scope parameters
      in
      pure nested body
  | _ -> false

let stable_value value =
  value.expression <> None
  || not
       (List.exists
          (fun name -> has_attribute name value.attributes)
          [
            "val";
            "get";
            "send";
            "module";
            "bs.val";
            "bs.get";
            "bs.send";
            "bs.module";
          ])

let stable scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name ->
      Option.fold ~none:false ~some:stable_value (resolve scope name.txt)
  | Pexp_constant _ -> true
  | _ -> false

let bind_value scope (binding : Parsetree.value_binding) =
  let typ =
    match pattern_type scope binding.pvb_pat with
    | Unknown -> infer scope binding.pvb_expr
    | typ -> typ
  in
  let nested = bind_pattern scope typ binding.pvb_pat in
  match pattern_name binding.pvb_pat with
  | None -> nested
  | Some name ->
      let alias =
        match (unwrap binding.pvb_expr).pexp_desc with
        | Pexp_ident name -> resolve scope name.txt
        | _ -> None
      in
      let value =
        {
          identity = identity binding.pvb_pat.ppat_loc;
          typ;
          api = None;
          pure =
            has_attribute "lint.pure" binding.pvb_attributes
            || callable_pure scope binding.pvb_expr;
          expression = Some binding.pvb_expr;
          attributes = binding.pvb_attributes;
          canonical = None;
        }
      in
      let value =
        match alias with
        | None -> value
        | Some alias ->
            {
              alias with
              identity =
                (if stable_value alias then alias.identity else value.identity);
              expression =
                (if stable_value alias then alias.expression
                 else Some binding.pvb_expr);
              typ = value.typ;
              attributes = binding.pvb_attributes @ alias.attributes;
              pure = value.pure || alias.pure;
            }
      in
      add_value name value nested

let add_declaration scope (declaration : Parsetree.type_declaration) =
  let typ =
    match declaration.ptype_kind with
    | Ptype_record fields ->
        Record
          (List.map
             (fun (field : Parsetree.label_declaration) ->
               ( field.pld_name.txt,
                 type_of scope field.pld_type,
                 field.pld_mutable = Asttypes.Mutable ))
             fields)
    | Ptype_variant constructors ->
        Variant
          (List.exists
             (fun (constructor : Parsetree.constructor_declaration) ->
               match constructor.pcd_args with
               | Pcstr_tuple [] -> false
               | _ -> true)
             constructors)
    | _ ->
        Option.fold ~none:Unknown ~some:(type_of scope)
          declaration.ptype_manifest
  in
  let scope = add_type declaration.ptype_name.txt typ scope in
  match declaration.ptype_kind with
  | Ptype_variant constructors ->
      List.fold_left
        (fun scope (constructor : Parsetree.constructor_declaration) ->
          add_constructor constructor.pcd_name.txt typ scope)
        scope constructors
  | _ -> scope

let external_value scope (value : Parsetree.value_description) =
  let global =
    not
      (List.exists
         (fun name -> has_attribute name value.pval_attributes)
         [ "scope"; "module"; "bs.scope"; "bs.module" ])
  in
  let api =
    match value.pval_prim with
    | [ "eval" ] when global && has_attribute "val" value.pval_attributes ->
        Some [ "Global"; "eval" ]
    | [ "Function" ] when global && has_attribute "new" value.pval_attributes ->
        Some [ "Global"; "Function" ]
    | _ -> None
  in
  {
    (unknown_value value.pval_loc) with
    typ = type_of scope value.pval_type;
    attributes = value.pval_attributes;
    api;
    pure = has_attribute "lint.pure" value.pval_attributes;
  }

let add_external scope (value : Parsetree.value_description) =
  add_value value.pval_name.txt (external_value scope value) scope

let rec signature ?(prefix = []) outer items =
  List.fold_left
    (signature_item prefix outer)
    { empty with origin = Some prefix }
    items

and signature_item prefix outer exports (item : Parsetree.signature_item) =
  let scope = overlay outer exports in
  match item.psig_desc with
  | Psig_value value ->
      add_value value.pval_name.txt
        {
          (external_value scope value) with
          canonical = Some (prefix @ [ value.pval_name.txt ]);
        }
        exports
  | Psig_type (_, declarations) ->
      List.fold_left add_declaration exports declarations
  | Psig_module binding ->
      let nested =
        signature_module
          (prefix @ [ binding.pmd_name.txt ])
          scope binding.pmd_type
      in
      add_module binding.pmd_name.txt nested exports
  | Psig_include inclusion ->
      overlay exports (signature_module prefix scope inclusion.pincl_mod)
  | _ -> exports

and signature_module prefix scope (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> signature ~prefix scope items
  | Pmty_alias name | Pmty_typeof { pmod_desc = Pmod_ident name; _ } ->
      Option.value ~default:unknown
        (Option.bind (path name.txt) (module_path scope))
  | Pmty_typeof { pmod_desc = Pmod_constraint (_, typ); _ } ->
      signature_module prefix scope typ
  | _ -> { unknown with origin = Some prefix }

let builtin scope module_name member arity result pure =
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
    }
    scope

let runtime_module name =
  let functions =
    match name with
    | "Array" ->
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
        ]
    | "List" ->
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
        ]
    | "String" ->
        [
          ("length", 1, Int, true);
          ("isEmpty", 1, Bool, true);
          ("get", 2, Option String, true);
          ("getUnsafe", 2, String, true);
        ]
    | "Option" ->
        [
          ("getExn", 1, Unknown, false);
          ("getOrThrow", 1, Unknown, false);
          ("getUnsafe", 1, Unknown, true);
          ("ignore", 1, Unit, true);
        ]
    | "Result" ->
        [
          ("getExn", 1, Unknown, false);
          ("getOrThrow", 1, Unknown, false);
          ("ignore", 1, Unit, true);
        ]
    | "Promise" ->
        [
          ("resolve", 1, Promise Unknown, false);
          ("reject", 1, Promise Unknown, false);
          ("make", 1, Promise Unknown, false);
          ("then", 2, Promise Unknown, false);
          ("thenResolve", 2, Promise Unknown, false);
          ("all", 1, Promise (Array Unknown), false);
          ("ignore", 1, Unit, true);
        ]
    | "Int" ->
        [ ("fromString", 1, Option Int, true); ("toString", 1, String, true) ]
    | "Console" ->
        [
          ("log", 1, Unit, false);
          ("info", 1, Unit, false);
          ("warn", 1, Unit, false);
          ("error", 1, Unit, false);
        ]
    | _ -> []
  in
  List.fold_left
    (fun scope (member, arity, result, pure) ->
      builtin scope name member arity result pure)
    { empty with origin = Some [ name ] }
    functions

let runtime =
  let scope =
    List.fold_left
      (fun scope name ->
        let nested = runtime_module name in
        add_module ("Stdlib_" ^ name) nested (add_module name nested scope))
      empty
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
      ]
  in
  let scope =
    List.fold_left
      (fun scope name ->
        builtin scope "Stdlib" name 2 Unknown
          (not (List.mem name [ "/"; "mod"; "=="; "!="; "<"; "<="; ">"; ">=" ])))
      scope operators
  in
  let scope = builtin scope "Stdlib" "ignore" 1 Unit true in
  let scope =
    add_constructor "None" (Option Unknown)
      (add_constructor "Some" (Option Unknown) scope)
  in
  let scope =
    add_constructor "Ok" (Result Unknown)
      (add_constructor "Error" (Result Unknown) scope)
  in
  add_module "Stdlib" scope scope

let runtime_types scope =
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

let initial context =
  let runtime = runtime_types runtime in
  let runtime = add_module "Stdlib" runtime runtime in
  let scope =
    List.fold_left
      (fun scope name -> add_module name unknown scope)
      runtime context.project_modules
  in
  let populate scope =
    List.fold_left
      (fun scope (name, items) ->
        add_module name (signature ~prefix:[ name ] scope items) scope)
      scope context.module_signatures
  in
  let rec settle remaining scope =
    if remaining = 0 then scope
    else
      let next = populate scope in
      if next = scope then next else settle (remaining - 1) next
  in
  settle (List.length context.module_signatures + 1) scope
