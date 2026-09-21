type reporter = {
  finding : Location.t -> string -> unit;
  unsupported : Location.t -> string -> unit;
  analyze_bodies : bool;
  project : bool;
}

type context = { scope : Throws_scope.t; handlers : Throws_handler.t }

let rec unwrap (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) | Pexp_newtype (_, inner) -> unwrap inner
  | _ -> expression

let identifier expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name ->
      Option.map
        (fun path -> (path, name.loc))
        (Throws_annotation.path name.txt)
  | _ -> None

let decode reporter scope attributes =
  match Throws_annotation.decode attributes with
  | Error error ->
      reporter.unsupported error.location error.message;
      None
  | Ok None -> None
  | Ok (Some annotation) -> (
      match Throws_scope.resolve scope annotation with
      | Ok contract -> Some contract
      | Error (Throws_scope.Unresolved_exception path) ->
          let message =
            "Cannot resolve exception " ^ String.concat "." path
            ^ ". Its declaration must be available in the current throws scope."
          in
          List.iter
            (fun ((name : string Location.loc), _) ->
              reporter.unsupported name.loc message)
            (List.filter Throws_annotation.is_throws attributes);
          None)

let annotated reporter scope attributes =
  Option.fold ~none:Throws_scope.Plain
    ~some:(fun contract -> Throws_scope.Annotated contract)
    (decode reporter scope attributes)

let binding_callable reporter scope (binding : Parsetree.value_binding) =
  match decode reporter scope binding.pvb_attributes with
  | Some contract -> (
      match (unwrap binding.pvb_expr).pexp_desc with
      | Pexp_fun { async = false; _ } -> Throws_scope.Annotated contract
      | _ ->
          reporter.unsupported binding.pvb_loc
            "Annotated declarations must be synchronous functions; annotated \
             aliases and async functions are not supported.";
          Plain)
  | None ->
      Option.fold ~none:Throws_scope.Plain
        ~some:(fun (path, location) ->
          match Throws_scope.value scope path with
          | Some callable -> callable
          | None ->
              if (not reporter.analyze_bodies) && List.length path > 1 then
                reporter.unsupported location
                  ("Cannot resolve exported alias " ^ String.concat "." path
                 ^ ". Its throws contract is unavailable.");
              Throws_scope.Plain)
        (identifier binding.pvb_expr)

let rec return_type remaining (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_arrow { ret; _ } when remaining > 0 -> return_type (remaining - 1) ret
  | _ -> typ

let synchronous_external (typ : Parsetree.core_type) =
  match typ.ptyp_desc with
  | Ptyp_arrow { arity; _ } -> (
      let result = return_type (Option.value ~default:1 arity) typ in
      match result.ptyp_desc with
      | Ptyp_arrow _ -> false
      | Ptyp_constr (name, _) ->
          not
            (List.mem
               (Throws_annotation.path name.txt)
               [ Some [ "promise" ]; Some [ "Promise"; "t" ] ])
      | _ -> true)
  | _ -> false

let external_callable reporter scope (declaration : Parsetree.value_description)
    =
  let callable = annotated reporter scope declaration.pval_attributes in
  (match callable with
  | Annotated _ when not (synchronous_external declaration.pval_type) ->
      reporter.unsupported declaration.pval_loc
        "Annotated external/interface declarations need a direct synchronous \
         function type; promise results and returned functions are not \
         supported."
  | _ -> ());
  callable

let unknown reporter location path =
  reporter.unsupported location
    ("Cannot resolve " ^ String.concat "." path
   ^ ". Its callable contract is not available in the current throws scope.")

let inspect_reference reporter context expression =
  Option.iter
    (fun (path, location) ->
      match Throws_scope.value context.scope path with
      | Some (Annotated _) ->
          reporter.unsupported location
            "Cannot verify an annotated function escaping as a value. Use a \
             direct call or a simple named alias."
      | None when List.length path > 1 -> unknown reporter location path
      | _ -> ())
    (identifier expression)

let rec inspect_call reporter context ~partial expression =
  Option.iter
    (fun (path, location) ->
      match Throws_scope.value context.scope path with
      | Some (Annotated contract) ->
          if partial then
            reporter.unsupported location
              "Partial application of an annotated function requires \
               deferred-call analysis, which is not supported."
          else report_missing reporter context location path contract
      | None when List.length path > 1 -> unknown reporter location path
      | _ -> ())
    (identifier expression)

and report_missing reporter context location path contract =
  match Throws_handler.missing context.handlers contract with
  | [] -> ()
  | missing ->
      reporter.finding location
        ("Handle " ^ String.concat ", " missing ^ " when calling "
       ^ String.concat "." path
       ^ ". Use try/catch or switch exception patterns; caller annotations do \
          not handle exceptions.")

let fresh scope = { scope; handlers = Throws_handler.empty }

let with_pattern context pattern =
  { context with scope = Throws_scope.bind_pattern Plain pattern context.scope }

let rec iterator reporter context : Ast_iterator.iterator =
  let default = Ast_iterator.default_iterator in
  {
    default with
    expr = (fun _ expression -> visit reporter context expression);
    structure = (fun _ items -> ignore (structure reporter context items));
    signature = (fun _ items -> ignore (signature reporter context.scope items));
    module_expr =
      (fun _ expression ->
        ignore (module_expression reporter context expression));
    attributes = (fun _ _ -> ());
  }

and visit reporter context (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ident _ -> inspect_reference reporter context expression
  | Pexp_apply { funct; args; partial; _ } ->
      application reporter context ~partial funct args
  | Pexp_fun { arity; _ } ->
      if reporter.analyze_bodies then
        parameters reporter (fresh context.scope)
          (Option.value ~default:1 arity)
          expression
  | Pexp_let (recursive, bindings, body) ->
      let scope, _ = bindings_scope reporter context recursive bindings in
      visit reporter { context with scope } body
  | _ -> handlers_and_scopes reporter context expression

and handlers_and_scopes reporter context expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_try (body, cases) ->
      protected_expression reporter context
        (Throws_handler.catches context.scope cases)
        body;
      List.iter (visit_case reporter context) cases
  | Pexp_match (body, cases) ->
      protected_expression reporter context
        (Throws_handler.switches context.scope cases)
        body;
      List.iter (visit_case reporter context) cases
  | Pexp_letmodule (name, expression, body) ->
      let contents = module_expression reporter context expression in
      visit reporter
        {
          context with
          scope = Throws_scope.add_module name.txt contents context.scope;
        }
        body
  | Pexp_letexception (declaration, body) ->
      let scope =
        Throws_scope.bind_exception
          ~filename:declaration.pext_loc.loc_start.pos_fname declaration
          context.scope
      in
      visit reporter { context with scope } body
  | _ -> remaining_expression reporter context expression

and remaining_expression reporter context expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_open (_, name, body) ->
      let scope =
        Throws_scope.overlay context.scope
          (resolve_module reporter context.scope name)
      in
      visit reporter { context with scope } body
  | Pexp_await body ->
      reporter.unsupported expression.pexp_loc
        "Await/promise rejection analysis is not supported by the source-local \
         throws rule.";
      visit reporter context body
  | Pexp_for (pattern, first, last, _, body) ->
      visit reporter context first;
      visit reporter context last;
      visit reporter (with_pattern context pattern) body
  | _ ->
      Ast_iterator.default_iterator.expr (iterator reporter context) expression

and protected_expression reporter context handlers expression =
  visit reporter
    { context with handlers = Throws_handler.union context.handlers handlers }
    expression

and visit_case reporter context (case : Parsetree.case) =
  let context = with_pattern context case.pc_lhs in
  Option.iter (visit reporter context) case.pc_guard;
  visit reporter context case.pc_rhs

and parameters reporter context remaining expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_fun { default; lhs; rhs; _ } when remaining > 0 ->
      Option.iter (visit reporter context) default;
      parameters reporter (with_pattern context lhs) (remaining - 1) rhs
  | _ -> visit reporter context expression

and application reporter context ~partial funct args =
  match (identifier funct, args) with
  | Some ([ "->" ], _), [ (_, value); (_, target) ] ->
      visit reporter context value;
      call_target reporter context ~partial:false target
  | _ ->
      if reporter.analyze_bodies || partial then
        inspect_call reporter context ~partial funct;
      if Option.is_none (identifier funct) then visit reporter context funct;
      List.iter (fun (_, argument) -> visit reporter context argument) args

and call_target reporter context ~partial expression =
  match identifier expression with
  | Some _ ->
      if reporter.analyze_bodies || partial then
        inspect_call reporter context ~partial expression
  | None -> visit reporter context expression

and bindings_scope reporter context recursive bindings =
  let entries =
    List.map
      (fun binding ->
        (binding, binding_callable reporter context.scope binding))
      bindings
  in
  let bind scope (binding, callable) =
    Throws_scope.bind_pattern callable binding.Parsetree.pvb_pat scope
  in
  let additions = List.fold_left bind Throws_scope.empty entries in
  let after = Throws_scope.overlay context.scope additions in
  let inside =
    match recursive with
    | Asttypes.Recursive -> after
    | Nonrecursive -> context.scope
  in
  List.iter (binding_value reporter { context with scope = inside }) entries;
  (after, additions)

and binding_value reporter context (binding, callable) =
  match identifier binding.Parsetree.pvb_expr with
  | Some _ when not reporter.analyze_bodies -> ()
  | Some _ when callable <> Throws_scope.Plain -> ()
  | _ -> visit reporter context binding.pvb_expr

and resolve_module reporter scope (name : Longident.t Location.loc) =
  match
    Option.bind
      (Throws_annotation.path name.txt)
      (Throws_scope.module_scope scope)
  with
  | Some contents -> contents
  | None ->
      reporter.unsupported name.loc
        "Cannot resolve this module's declarations for throws analysis.";
      Throws_scope.empty

and module_expression reporter context expression =
  match expression.Parsetree.pmod_desc with
  | Pmod_structure items -> snd (structure reporter context items)
  | Pmod_ident name -> resolve_module reporter context.scope name
  | _ ->
      reporter.unsupported expression.pmod_loc
        "Constrained, recursive, functor, and unpacked modules require \
         semantic throws metadata and are not supported.";
      if reporter.analyze_bodies then
        Ast_iterator.default_iterator.module_expr
          (iterator reporter context)
          expression;
      Throws_scope.empty

and structure reporter context items =
  List.fold_left
    (fun (scope, exports) item ->
      let scope, added = structure_item reporter { context with scope } item in
      (scope, Throws_scope.overlay exports added))
    (context.scope, Throws_scope.empty)
    items

and structure_item reporter context item =
  match item.Parsetree.pstr_desc with
  | Pstr_value (recursive, bindings) ->
      bindings_scope reporter context recursive bindings
  | Pstr_primitive declaration ->
      let added =
        Throws_scope.add_value declaration.pval_name.txt
          (external_callable reporter context.scope declaration)
          Throws_scope.empty
      in
      (Throws_scope.overlay context.scope added, added)
  | Pstr_module binding ->
      let added =
        Throws_scope.add_module binding.pmb_name.txt
          (module_expression reporter context binding.pmb_expr)
          Throws_scope.empty
      in
      (Throws_scope.overlay context.scope added, added)
  | _ -> structure_declaration reporter context item

and structure_declaration reporter context item =
  let added =
    match item.Parsetree.pstr_desc with
    | Pstr_exception declaration -> exception_export context.scope declaration
    | Pstr_type (_, declarations) ->
        Throws_scope.shadow_types declarations Throws_scope.empty
    | Pstr_include inclusion ->
        module_expression reporter context inclusion.pincl_mod
    | _ -> Throws_scope.empty
  in
  let scope = Throws_scope.overlay context.scope added in
  structure_other reporter { context with scope } item;
  (scope_after_open reporter scope item, added)

and exception_export scope declaration =
  Throws_scope.exception_export
    ~filename:declaration.Parsetree.pext_loc.loc_start.pos_fname scope
    declaration

and scope_after_open reporter scope item =
  match item.Parsetree.pstr_desc with
  | Pstr_open opening ->
      Throws_scope.overlay scope
        (resolve_module reporter scope opening.popen_lid)
  | _ -> scope

and structure_other reporter context item =
  match item.Parsetree.pstr_desc with
  | Pstr_eval (expression, _) when reporter.analyze_bodies ->
      visit reporter context expression
  | Pstr_recmodule _ | Pstr_typext _ | Pstr_modtype _ ->
      reporter.unsupported item.pstr_loc
        "Recursive modules, module types, and type extensions require semantic \
         throws metadata and are not supported."
  | _ -> ()

and signature reporter scope items =
  List.fold_left
    (fun (scope, exports) item ->
      let after, added = signature_item reporter scope item in
      (after, Throws_scope.overlay exports added))
    (scope, Throws_scope.empty)
    items

and signature_item reporter scope item =
  match item.Parsetree.psig_desc with
  | Psig_open opening when reporter.project ->
      ( Throws_scope.overlay scope
          (resolve_module reporter scope opening.popen_lid),
        Throws_scope.empty )
  | _ -> signature_declaration reporter scope item

and signature_declaration reporter scope item =
  let added =
    match item.Parsetree.psig_desc with
    | Psig_value declaration ->
        Throws_scope.add_value declaration.pval_name.txt
          (external_callable reporter scope declaration)
          Throws_scope.empty
    | Psig_exception declaration ->
        Throws_scope.exception_export
          ~filename:declaration.pext_loc.loc_start.pos_fname scope declaration
    | Psig_type (_, declarations) ->
        Throws_scope.shadow_types declarations Throws_scope.empty
    | Psig_module declaration -> signature_module reporter scope declaration
    | Psig_include inclusion when reporter.project ->
        signature_type reporter scope inclusion.pincl_mod
    | _ -> signature_other reporter item
  in
  (Throws_scope.overlay scope added, added)

and signature_other reporter item =
  (match item.Parsetree.psig_desc with
  | Psig_recmodule _ | Psig_modtype _ | Psig_include _ | Psig_open _
  | Psig_typext _ ->
      reporter.unsupported item.psig_loc
        "This interface declaration requires semantic throws metadata."
  | _ -> ());
  Throws_scope.empty

and signature_module reporter scope declaration =
  if reporter.project then
    Throws_scope.add_module declaration.Parsetree.pmd_name.txt
      (signature_type reporter scope declaration.pmd_type)
      Throws_scope.empty
  else
    match declaration.Parsetree.pmd_type.pmty_desc with
    | Pmty_signature items ->
        let _, exports = signature reporter scope items in
        reporter.unsupported declaration.pmd_loc
          "Nested interface modules are not indexed by source-local throws \
           analysis yet.";
        Throws_scope.add_module declaration.pmd_name.txt exports
          Throws_scope.empty
    | _ ->
        reporter.unsupported declaration.pmd_loc
          "This interface module requires semantic throws metadata.";
        Throws_scope.empty

and signature_type reporter scope (typ : Parsetree.module_type) =
  match typ.pmty_desc with
  | Pmty_signature items -> snd (signature reporter scope items)
  | Pmty_alias name | Pmty_typeof { pmod_desc = Pmod_ident name; _ } ->
      resolve_module reporter scope name
  | _ ->
      reporter.unsupported typ.pmty_loc
        "This module type cannot provide resolved throws declarations.";
      Throws_scope.empty

let has_annotations tree =
  let found = ref false in
  let visitor =
    {
      Ast_iterator.default_iterator with
      attribute =
        (fun _ attribute ->
          if Throws_annotation.is_throws attribute then found := true);
    }
  in
  (match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items);
  !found

let validate_placements ?(declarations_only = false) reporter tree =
  let visitor =
    {
      Ast_iterator.default_iterator with
      attribute =
        (fun _ (((name : string Location.loc), _) as attribute) ->
          if Throws_annotation.is_throws attribute then
            reporter.unsupported name.loc
              "Throws annotations are supported on named function, external, \
               or interface declarations only.");
      value_binding =
        (fun self binding ->
          self.pat self binding.Parsetree.pvb_pat;
          self.expr self binding.pvb_expr);
      value_description =
        (fun self declaration -> self.typ self declaration.Parsetree.pval_type);
      expr =
        (fun self expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_ident name
            when Option.is_none (Throws_annotation.path name.txt) ->
              reporter.unsupported name.loc
                "Functor-qualified values require semantic throws metadata."
          | _ -> ());
          if declarations_only then
            self.attributes self expression.pexp_attributes
          else Ast_iterator.default_iterator.expr self expression);
    }
  in
  match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items

let collect ~(source : Source.t) ~project ~analyze_bodies run =
  let findings = ref [] and errors = ref [] in
  let emit destination rule location message =
    destination :=
      Diagnostic.
        {
          filename = source.filename;
          rule;
          message;
          fixes = [];
          range = Source_range.of_location ~source:source.text location;
        }
      :: !destination
  in
  let reporter =
    {
      finding = emit findings "no-unhandled-throws";
      unsupported = emit errors "throws-analysis";
      project;
      analyze_bodies;
    }
  in
  let result = run reporter in
  ( result,
    Source_range.sort (List.rev !findings),
    Source_range.sort (List.rev !errors) )

let check ?scope ~(source : Source.t) tree =
  let initial = Option.value ~default:Throws_scope.initial scope in
  let _, findings, errors =
    collect ~source ~project:(Option.is_some scope) ~analyze_bodies:true
      (fun reporter ->
        if Option.is_some scope || has_annotations tree then (
          validate_placements reporter tree;
          match tree with
          | Parser.Implementation items ->
              ignore (structure reporter (fresh initial) items)
          | Interface items -> ignore (signature reporter initial items)))
  in
  match errors with
  | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
  | [] -> Ok findings

let exports ~scope ~(source : Source.t) tree =
  let exports, _, errors =
    collect ~source ~project:true ~analyze_bodies:false (fun reporter ->
        validate_placements ~declarations_only:true reporter tree;
        match tree with
        | Parser.Implementation items ->
            snd (structure reporter (fresh scope) items)
        | Interface items -> snd (signature reporter scope items))
  in
  (exports, errors)
