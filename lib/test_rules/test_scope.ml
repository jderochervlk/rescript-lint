module Names = Map.Make (String)

type registration_kind = Test | Describe

type registration = {
  kind : registration_kind;
  title_index : int;
  todo : bool;
  focused : bool;
}

type hook = Before_all | Before_each | After_each | After_all

type value =
  | Unknown
  | Registration of registration
  | Hook of hook
  | Assertion
  | Skip
  | Skip_if
  | Function of Parsetree.expression * t

and t = { values : value Names.t; modules : t Names.t; opaque : bool }

let empty = { values = Names.empty; modules = Names.empty; opaque = false }
let unknown = { empty with opaque = true }

let add_value name value scope =
  { scope with values = Names.add name value scope.values }

let add_module name value scope =
  { scope with modules = Names.add name value scope.modules }

let overlay outer inner =
  let merge outer inner =
    Names.union (fun _ _ inner -> Some inner) outer inner
  in
  if inner.opaque then inner
  else
    {
      values = merge outer.values inner.values;
      modules = merge outer.modules inner.modules;
      opaque = outer.opaque;
    }

let registration ?(title_index = 0) ?(todo = false) kind =
  Registration { kind; title_index; todo; focused = false }

let add_values names value scope =
  List.fold_left (fun scope name -> add_value name value scope) scope names

let runner ?(title_index = 0) ?(todo = false) () =
  empty
  |> add_values
       [ "test"; "it"; "testAsync"; "itAsync" ]
       (registration ~title_index ~todo Test)
  |> add_value "describe" (registration ~title_index ~todo Describe)

let assertions names = add_values names Assertion empty

let matcher_scope =
  let numeric =
    assertions
      [
        "toBeGreaterThan";
        "toBeGreaterThanOrEqual";
        "toBeLessThan";
        "toBeLessThanOrEqual";
      ]
  in
  let collection =
    assertions [ "toContain"; "toContainEqual"; "toHaveLength"; "toMatch" ]
  in
  assertions
    [
      "toBe";
      "eq";
      "toBeDefined";
      "toBeUndefined";
      "toBeTruthy";
      "toBeFalsy";
      "toBeNull";
      "toEqual";
      "toBeSome";
      "toBeNone";
      "toStrictEqual";
      "toContain";
      "toContainEqual";
      "toMatchSnapshot";
      "toThrow";
      "toThrowError";
    ]
  |> add_module "Int" numeric
  |> add_module "Float"
       (add_values [ "toBeNaN"; "toBeCloseTo" ] Assertion numeric)
  |> add_module "String" (assertions [ "toContain"; "toHaveLength"; "toMatch" ])
  |> add_module "Array" collection
  |> add_module "List" collection
  |> add_module "Dict" (assertions [ "toHaveProperty"; "toHaveKey"; "toMatch" ])

let matchers = add_module "Promise" matcher_scope matcher_scope
let assert_scope = assertions [ "assert_"; "unreachable"; "equal"; "deepEqual" ]

let in_source =
  runner () |> add_value "expect" Assertion |> add_module "Expect" matchers

let bindings_scope = add_module "InSource" in_source empty

let vitest =
  runner ()
  |> add_value "beforeAll" (Hook Before_all)
  |> add_value "beforeAllAsync" (Hook Before_all)
  |> add_value "beforeEach" (Hook Before_each)
  |> add_value "beforeEachAsync" (Hook Before_each)
  |> add_value "afterEach" (Hook After_each)
  |> add_value "afterEachAsync" (Hook After_each)
  |> add_value "afterAll" (Hook After_all)
  |> add_value "afterAllAsync" (Hook After_all)
  |> add_values [ "expect"; "assertions"; "hasAssertion" ] Assertion
  |> add_value "skip" Skip |> add_value "skipIf" Skip_if
  |> add_module "For"
       (runner ~title_index:1 ()
       |> add_value "describeAsync" (registration ~title_index:1 Describe))
  |> add_module "Todo"
       (empty
       |> add_values [ "test"; "it" ] (registration ~todo:true Test)
       |> add_value "describe" (registration ~todo:true Describe))
  |> add_module "Expect" matchers
  |> add_module "Assert" assert_scope
  |> add_module "Bindings" bindings_scope
  |> add_module "InSource" in_source

let initial =
  empty |> add_module "Vitest" vitest
  |> add_module "Vitest_Matchers" matchers
  |> add_module "Vitest_Assert" assert_scope
  |> add_module "Vitest_Bindings" bindings_scope

let rec module_path scope = function
  | Longident.Lident name -> Names.find_opt name scope.modules
  | Ldot (parent, name) ->
      Option.bind (module_path scope parent) (fun scope ->
          Names.find_opt name scope.modules)
  | Lapply _ -> None

let value_path scope = function
  | Longident.Lident name ->
      Option.value ~default:Unknown (Names.find_opt name scope.values)
  | Ldot (parent, name) ->
      Option.fold ~none:Unknown
        ~some:(fun scope ->
          Option.value ~default:Unknown (Names.find_opt name scope.values))
        (module_path scope parent)
  | Lapply _ -> Unknown

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) | Pexp_newtype (_, inner) -> unwrap inner
  | _ -> expression

let expression scope value =
  let value = unwrap value in
  match value.pexp_desc with
  | Pexp_ident name -> value_path scope name.txt
  | Pexp_fun _ -> Function (value, scope)
  | _ -> Unknown

let rec bind_pattern value (pattern : Parsetree.pattern) scope =
  match pattern.ppat_desc with
  | Ppat_var name -> add_value name.txt value scope
  | Ppat_alias (inner, name) ->
      add_value name.txt value (bind_pattern value inner scope)
  | Ppat_constraint (inner, _) -> bind_pattern value inner scope
  | Ppat_unpack name -> add_module name.txt empty scope
  | _ -> bind_children pattern scope

and bind_children pattern scope =
  let result = ref scope in
  let visitor =
    {
      Ast_iterator.default_iterator with
      pat = (fun _ child -> result := bind_pattern Unknown child !result);
      attribute = (fun _ _ -> ());
    }
  in
  Ast_iterator.default_iterator.pat visitor pattern;
  !result

let bindings scope recursive bindings =
  let shadowed =
    List.fold_left
      (fun scope binding ->
        bind_pattern Unknown binding.Parsetree.pvb_pat scope)
      scope bindings
  in
  let inside = if recursive = Asttypes.Recursive then shadowed else scope in
  let exports =
    List.fold_left
      (fun exports binding ->
        bind_pattern
          (expression inside binding.Parsetree.pvb_expr)
          binding.pvb_pat exports)
      empty bindings
  in
  (inside, exports)

let attribute_string name attributes =
  List.find_map
    (fun ((key : string Location.loc), payload) ->
      match payload with
      | Parsetree.PStr
          [
            {
              pstr_desc =
                Pstr_eval
                  ({ pexp_desc = Pexp_constant (Pconst_string (text, _)); _ }, _);
              _;
            };
          ]
        when key.txt = name ->
          Some text
      | _ -> None)
    attributes

let ffi_registration name =
  match name with
  | "test" | "it" ->
      Some { kind = Test; title_index = 0; todo = false; focused = false }
  | "describe" | "suite" ->
      Some { kind = Describe; title_index = 0; todo = false; focused = false }
  | _ -> None

let ffi_member parent name =
  match ffi_registration parent with
  | Some registration when name = "only" ->
      Registration { registration with focused = true }
  | Some registration when name = "skip" || name = "todo" ->
      Registration { registration with todo = true }
  | _ -> Unknown

let ffi_direct name =
  match ffi_registration name with
  | Some value -> Registration value
  | None -> (
      match name with
      | "beforeAll" -> Hook Before_all
      | "beforeEach" -> Hook Before_each
      | "afterEach" -> Hook After_each
      | "afterAll" -> Hook After_all
      | "expect" | "assert" -> Assertion
      | _ -> Unknown)

let external_value (declaration : Parsetree.value_description) =
  match
    ( attribute_string "module" declaration.pval_attributes,
      declaration.pval_prim )
  with
  | Some "vitest", [ name ] -> (
      match attribute_string "scope" declaration.pval_attributes with
      | None -> ffi_direct name
      | Some parent -> ffi_member parent name)
  | _ -> Unknown

let rec constrain scope (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> List.fold_left (signature_item scope) empty items
  | _ -> unknown

and signature_item scope exports (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value value ->
      add_value value.pval_name.txt
        (value_path scope (Lident value.pval_name.txt))
        exports
  | Psig_module declaration ->
      let value =
        Option.value ~default:empty
          (Names.find_opt declaration.pmd_name.txt scope.modules)
      in
      add_module declaration.pmd_name.txt
        (constrain value declaration.pmd_type)
        exports
  | _ -> exports

let rec signature_exports items = List.fold_left signature_export empty items

and signature_export scope (item : Parsetree.signature_item) =
  match item.psig_desc with
  | Psig_value value -> add_value value.pval_name.txt Unknown scope
  | Psig_module declaration ->
      add_module declaration.pmd_name.txt
        (module_type_exports declaration.pmd_type)
        scope
  | Psig_recmodule declarations ->
      List.fold_left
        (fun scope declaration ->
          add_module declaration.Parsetree.pmd_name.txt
            (module_type_exports declaration.pmd_type)
            scope)
        scope declarations
  | Psig_include inclusion ->
      overlay scope (module_type_exports inclusion.pincl_mod)
  | _ -> scope

and module_type_exports (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> signature_exports items
  | Pmty_alias name ->
      Option.value ~default:unknown (module_path initial name.txt)
  | _ -> unknown

let with_module_signatures signatures =
  List.fold_left
    (fun scope (name, signature) ->
      add_module name (signature_exports signature) scope)
    initial signatures
