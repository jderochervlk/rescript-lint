let rule_ids =
  [
    "test/no-focused-tests";
    "test/no-disabled-tests";
    "test/no-identical-title";
    "test/no-duplicate-hooks";
    "test/no-conditional-test";
    "test/no-conditional-expect";
    "test/prefer-hooks-in-order";
    "test/prefer-hooks-on-top";
    "test/require-top-level-describe";
    "test/valid-title";
    "test/expect-expect";
    "test/max-nested-describe";
  ]

type context = {
  suite : int list;
  depth : int;
  test : int option;
  conditional : bool;
  calls : int list;
  active : bool;
}

type registration = {
  api : Test_scope.registration;
  title : (string * Location.t) option;
  flags : (string * Location.t) list;
  location : Location.t;
  key : int;
  context : context;
  callback_known : bool;
}

type event =
  | Registration of registration
  | Hook of Test_scope.hook * Location.t * context
  | Assertion of Location.t * Location.t * context
  | Disabled of Location.t

let initial =
  {
    suite = [];
    depth = 0;
    test = None;
    conditional = false;
    calls = [];
    active = true;
  }

let conditional context = { context with conditional = true }

let position (expression : Parsetree.expression) =
  expression.pexp_loc.loc_start.pos_cnum

let positional args =
  List.filter_map
    (function Asttypes.Nolabel, value -> Some value | _ -> None)
    args

let last values =
  match List.rev values with first :: _ -> Some first | [] -> None

let string_literal expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_string (value, None)) ->
      Some (value, expression.pexp_loc)
  | _ -> None

let rec is_true expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_construct ({ txt = Lident "true"; _ }, None) -> true
  | Pexp_construct ({ txt = Lident "Some"; _ }, Some inner) -> is_true inner
  | _ -> false

let flag name expression =
  if List.mem name [ "only"; "skip"; "todo" ] && is_true expression then
    Some (name, expression.Parsetree.pexp_loc)
  else None

let record_flags expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_record (fields, _) ->
      List.filter_map
        (fun (field : Parsetree.expression Parsetree.record_element) ->
          match field.lid.txt with
          | Lident name -> flag name field.x
          | _ -> None)
        fields
  | _ -> []

let flags args =
  List.concat_map
    (function
      | Asttypes.Labelled name, expression | Optional name, expression ->
          Option.to_list (flag name.txt expression)
      | Nolabel, expression -> record_flags expression)
    args

let callback scope api args =
  if api.Test_scope.todo then None
  else
    Option.bind
      (last (positional args))
      (fun expression ->
        match Test_scope.expression scope expression with
        | Function (body, captured) -> Some (body, captured)
        | _ -> None)

let rec application expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_apply
      {
        funct = { pexp_desc = Pexp_ident { txt = Lident "->"; _ }; _ };
        args = [ (Nolabel, value); (Nolabel, target) ];
        partial = false;
        _;
      } -> (
      match application target with
      | Some (funct, args, partial) ->
          Some (funct, (Asttypes.Nolabel, value) :: args, partial)
      | None -> Some (target, [ (Asttypes.Nolabel, value) ], false))
  | Pexp_apply { funct; args; partial; _ } -> Some (funct, args, partial)
  | _ -> None

let rec iterator emit scope context : Ast_iterator.iterator =
  {
    Ast_iterator.default_iterator with
    expr = (fun _ expression -> visit emit scope context expression);
    structure = (fun _ items -> ignore (structure emit scope context items));
    module_expr =
      (fun _ expression ->
        ignore (module_expression emit scope context expression));
    attribute = (fun _ _ -> ());
  }

and visit emit scope context expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_fun _ ->
      invoke emit scope
        { context with active = false; test = None; conditional = false }
        expression
  | Pexp_apply _ -> visit_application emit scope context expression
  | Pexp_let (recursive, bindings, body) ->
      let inside, exports = Test_scope.bindings scope recursive bindings in
      List.iter
        (fun binding -> visit emit inside context binding.Parsetree.pvb_expr)
        bindings;
      visit emit (Test_scope.overlay scope exports) context body
  | Pexp_open (_, name, body) ->
      let scope = opened scope name.txt in
      visit emit scope context body
  | _ -> visit_control_flow emit scope context (Test_scope.unwrap expression)

and visit_control_flow emit scope context expression =
  let walk = visit emit scope context in
  let branch = visit emit scope (conditional context) in
  match expression.Parsetree.pexp_desc with
  | Pexp_ifthenelse (condition, yes, no) ->
      walk condition;
      branch yes;
      Option.iter branch no
  | Pexp_match (value, cases) ->
      walk value;
      List.iter (visit_case emit scope (conditional context)) cases
  | Pexp_try (body, cases) ->
      visit emit scope
        {
          context with
          conditional = context.conditional || Option.is_some context.test;
        }
        body;
      List.iter (visit_case emit scope (conditional context)) cases
  | Pexp_while (condition, body) ->
      branch condition;
      branch body
  | Pexp_for (pattern, first, last, _, body) ->
      walk first;
      walk last;
      visit emit
        (Test_scope.bind_pattern Unknown pattern scope)
        (conditional context) body
  | _ -> visit_scoped emit scope context expression

and visit_scoped emit scope context expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_letmodule (name, binding, body) ->
      let contents = module_expression emit scope context binding in
      visit emit (Test_scope.add_module name.txt contents scope) context body
  | _ ->
      Ast_iterator.default_iterator.expr
        (iterator emit scope context)
        expression

and visit_case emit scope context (case : Parsetree.case) =
  let scope = Test_scope.bind_pattern Unknown case.pc_lhs scope in
  Option.iter (visit emit scope context) case.pc_guard;
  visit emit scope context case.pc_rhs

and visit_application emit scope context expression =
  match application expression with
  | Some
      ( { pexp_desc = Pexp_ident { txt = Lident ("&&" | "||"); _ }; _ },
        [ (_, left); (_, right) ],
        false ) ->
      visit emit scope context left;
      visit emit scope (conditional context) right
  | Some (funct, args, partial) ->
      List.iter (visit_argument emit scope context funct) args;
      if not partial then call emit scope context expression funct args
  | None -> ()

and visit_argument emit scope context funct (_, argument) =
  match
    (Test_scope.expression scope funct, (Test_scope.unwrap argument).pexp_desc)
  with
  | (Registration _ | Hook _), Pexp_fun _ -> ()
  | _ -> visit emit scope context argument

and call emit scope context expression funct args =
  match Test_scope.expression scope funct with
  | Registration api -> register emit scope context expression funct api args
  | Hook hook ->
      emit (Hook (hook, funct.Parsetree.pexp_loc, context));
      Option.iter
        (invoke_callback emit scope
           { context with test = None; conditional = false })
        (last (positional args))
  | Assertion -> emit (Assertion (funct.pexp_loc, expression.pexp_loc, context))
  | Skip -> emit (Disabled funct.pexp_loc)
  | Skip_if ->
      if
        Option.fold ~none:false ~some:is_true (List.nth_opt (positional args) 1)
      then emit (Disabled funct.pexp_loc)
  | Function (body, captured) -> invoke emit captured context body
  | Unknown -> visit emit scope context funct

and register emit scope context expression funct api args =
  let callback = callback scope api args in
  let key = position expression in
  let title =
    Option.bind
      (List.nth_opt (positional args) api.Test_scope.title_index)
      string_literal
  in
  emit
    (Registration
       {
         api;
         title;
         flags = flags args;
         location = funct.Parsetree.pexp_loc;
         key;
         context;
         callback_known = Option.is_some callback;
       });
  let nested =
    match api.kind with
    | Test -> { context with test = Some key; conditional = false }
    | Describe ->
        {
          context with
          suite = key :: context.suite;
          depth = context.depth + 1;
          test = None;
          conditional = false;
        }
  in
  Option.iter
    (fun (body, captured) -> invoke emit captured nested body)
    callback

and invoke_callback emit scope context expression =
  match Test_scope.expression scope expression with
  | Function (body, captured) -> invoke emit captured context body
  | _ -> ()

and invoke emit scope context expression =
  let key = position expression in
  if not (List.mem key context.calls) then
    let context = { context with calls = key :: context.calls } in
    match (Test_scope.unwrap expression).pexp_desc with
    | Pexp_fun { arity; _ } ->
        parameters emit scope context (Option.value ~default:1 arity) expression
    | _ -> ()

and parameters emit scope context remaining expression =
  match (Test_scope.unwrap expression).pexp_desc with
  | Pexp_fun { default; lhs; rhs; _ } when remaining > 0 ->
      Option.iter (visit emit scope (conditional context)) default;
      parameters emit
        (Test_scope.bind_pattern Unknown lhs scope)
        context (remaining - 1) rhs
  | _ -> visit emit scope context expression

and opened scope name =
  match Test_scope.module_path scope name with
  | Some contents -> Test_scope.overlay scope contents
  | None -> Test_scope.unknown

and module_expression emit scope context (expression : Parsetree.module_expr) =
  match expression.pmod_desc with
  | Pmod_ident name ->
      Option.value ~default:Test_scope.unknown
        (Test_scope.module_path scope name.txt)
  | Pmod_structure items -> structure emit scope context items
  | Pmod_constraint (inner, typ) ->
      Test_scope.constrain (module_expression emit scope context inner) typ
  | _ -> Test_scope.unknown

and structure emit scope context items =
  let rec loop scope exports = function
    | [] -> exports
    | item :: rest ->
        let scope, additions = structure_item emit scope context item in
        loop scope (Test_scope.overlay exports additions) rest
  in
  loop scope Test_scope.empty items

and structure_item emit scope context (item : Parsetree.structure_item) =
  let add additions = (Test_scope.overlay scope additions, additions) in
  match item.pstr_desc with
  | Pstr_value (recursive, bindings) ->
      let inside, exports = Test_scope.bindings scope recursive bindings in
      List.iter
        (fun binding -> visit emit inside context binding.Parsetree.pvb_expr)
        bindings;
      add exports
  | Pstr_primitive declaration ->
      add
        (Test_scope.add_value declaration.pval_name.txt
           (Test_scope.external_value declaration)
           Test_scope.empty)
  | Pstr_module binding ->
      add
        (Test_scope.add_module binding.pmb_name.txt
           (module_expression emit scope context binding.pmb_expr)
           Test_scope.empty)
  | Pstr_recmodule bindings ->
      let shadowed =
        List.fold_left
          (fun scope binding ->
            Test_scope.add_module binding.Parsetree.pmb_name.txt
              Test_scope.unknown scope)
          scope bindings
      in
      let exports =
        List.fold_left
          (fun exports binding ->
            Test_scope.add_module binding.Parsetree.pmb_name.txt
              (module_expression emit shadowed context binding.pmb_expr)
              exports)
          Test_scope.empty bindings
      in
      add exports
  | Pstr_open opening -> (opened scope opening.popen_lid.txt, Test_scope.empty)
  | Pstr_include inclusion ->
      add (module_expression emit scope context inclusion.pincl_mod)
  | _ ->
      Ast_iterator.default_iterator.structure_item
        (iterator emit scope context)
        item;
      (scope, Test_scope.empty)

let hook_rank = function
  | Test_scope.Before_all -> 0
  | Before_each -> 1
  | After_each -> 2
  | After_all -> 3

let report_flags emit registration =
  if registration.api.focused then
    emit "test/no-focused-tests" "Remove this focused test or suite."
      registration.location;
  if registration.api.todo then
    emit "test/no-disabled-tests" "Enable this disabled test or suite."
      registration.location;
  List.iter
    (fun (name, location) ->
      if name = "only" then
        emit "test/no-focused-tests" "Remove this focused test or suite."
          location
      else
        emit "test/no-disabled-tests" "Enable this disabled test or suite."
          location)
    registration.flags

let report_placement emit maximum registration =
  match registration.api.kind with
  | Test when registration.context.depth = 0 ->
      emit "test/require-top-level-describe"
        "Place this test inside a top-level describe suite."
        registration.location
  | Describe when registration.context.depth + 1 > maximum ->
      emit "test/max-nested-describe"
        (Printf.sprintf "Suite nesting exceeds the configured maximum of %d."
           maximum)
        registration.location
  | _ -> ()

let report_registration emit maximum registration =
  report_flags emit registration;
  Option.iter
    (fun (title, location) ->
      if String.trim title = "" then
        emit "test/valid-title" "Give this test or suite a nonempty title."
          location)
    registration.title;
  if registration.context.conditional then
    emit "test/no-conditional-test" "Register tests and suites unconditionally."
      registration.location;
  if registration.context.active then report_placement emit maximum registration

let assertion_owner = function
  | Assertion (_, _, { test = Some key; _ }) -> Some key
  | _ -> None

let report_missing_assertions emit events registration =
  if
    registration.api.kind = Test_scope.Test
    && registration.callback_known
    && (not registration.api.todo)
    && (not (List.exists (fun (name, _) -> name = "todo") registration.flags))
    && not
         (List.exists
            (fun event -> assertion_owner event = Some registration.key)
            events)
  then
    emit "test/expect-expect"
      "This test callback contains no recognized assertion."
      registration.location

let same_suite context = function
  | Registration value ->
      context.active && value.context.active
      && context.suite = value.context.suite
  | Hook (_, _, other) | Assertion (_, _, other) ->
      context.active && other.active && context.suite = other.suite
  | Disabled _ -> false

let report_title emit previous registration =
  Option.iter
    (fun (title, location) ->
      let duplicate =
        List.exists
          (function
            | Registration earlier ->
                earlier.api.kind = registration.api.kind
                && Option.map fst earlier.title = Some title
            | _ -> false)
          previous
      in
      if duplicate then
        emit "test/no-identical-title"
          "This sibling test or suite repeats an earlier title." location)
    registration.title

let report_hook emit previous hook location =
  if
    List.exists
      (function Hook (earlier, _, _) -> earlier = hook | _ -> false)
      previous
  then
    emit "test/no-duplicate-hooks" "Combine duplicate hooks in this suite."
      location;
  if
    List.exists
      (function
        | Hook (earlier, _, _) -> hook_rank earlier > hook_rank hook
        | _ -> false)
      previous
  then
    emit "test/prefer-hooks-in-order"
      "Order hooks as beforeAll, beforeEach, afterEach, afterAll." location;
  if List.exists (function Registration _ -> true | _ -> false) previous then
    emit "test/prefer-hooks-on-top"
      "Declare hooks before this suite's tests and nested suites." location

let nested_assertion events location expression context =
  List.exists
    (function
      | Assertion (inner, _, nested) ->
          nested.test = context.test
          && inner.loc_start.pos_cnum <> location.Location.loc_start.pos_cnum
          && inner.loc_start.pos_cnum >= expression.Location.loc_start.pos_cnum
          && inner.loc_end.pos_cnum <= expression.loc_end.pos_cnum
      | _ -> false)
    events

let report_event emit maximum events previous = function
  | Registration registration ->
      report_registration emit maximum registration;
      report_missing_assertions emit events registration;
      report_title emit
        (List.filter (same_suite registration.context) previous)
        registration
  | Hook (hook, location, context) ->
      report_hook emit (List.filter (same_suite context) previous) hook location
  | Assertion
      ( location,
        expression,
        ({ test = Some _; conditional = true; _ } as context) ) ->
      if not (nested_assertion events location expression context) then
        emit "test/no-conditional-expect"
          "Run this assertion unconditionally within the test." location
  | Assertion _ -> ()
  | Disabled location ->
      emit "test/no-disabled-tests" "Remove this runtime test skip." location

let check ?(max_nested_describe = 5) ?(module_signatures = [])
    ~(source : Source.t) tree =
  (* Accumulation is confined to the compiler visitor and diagnostic boundary. *)
  let events = ref [] in
  let record event = events := event :: !events in
  (match tree with
  | Parser.Implementation items ->
      ignore
        (structure record
           (Test_scope.with_module_signatures module_signatures)
           initial items)
  | Interface _ -> ());
  let events = List.rev !events in
  let findings = ref [] in
  let emit rule message location =
    findings :=
      Diagnostic.
        {
          filename = source.filename;
          rule;
          message;
          help = None;
          symbol = None;
          fixes = [];
          range = Source_range.of_location ~source:source.text location;
        }
      :: !findings
  in
  ignore
    (List.fold_left
       (fun previous event ->
         report_event emit max_nested_describe events previous event;
         event :: previous)
       [] events);
  List.sort_uniq
    (fun (left : Diagnostic.t) (right : Diagnostic.t) ->
      compare
        (left.range.start.byte_offset, left.range.finish.byte_offset, left.rule)
        ( right.range.start.byte_offset,
          right.range.finish.byte_offset,
          right.rule ))
    !findings
  |> Source_range.sort
