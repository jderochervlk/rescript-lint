type rule = { id : string; message : string list -> string option }

let initial (context : Semantic_model.context) =
  let scope =
    List.fold_left
      (fun scope name ->
        Semantic_model.add_module name Semantic_model.unknown scope)
      Banned_runtime.scope context.project_modules
  in
  let populate scope =
    List.fold_left
      (fun scope (name, items) ->
        Semantic_model.add_module name
          (Semantic_model.signature ~prefix:[ name ] scope items)
          scope)
      scope context.module_signatures
  in
  let rec settle remaining scope =
    if remaining = 0 then scope
    else
      let next = populate scope in
      if next = scope then next else settle (remaining - 1) next
  in
  settle (List.length context.module_signatures + 1) scope

let inspect ~emit scope (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_ident identifier ->
      Option.iter
        (fun value ->
          Option.iter
            (fun names -> emit names identifier.loc)
            value.Semantic_model.api)
        (Semantic_model.resolve scope identifier.txt)
  | _ -> ()

let report ~(source : Source.t) ~emit names location rule =
  Option.iter
    (fun message ->
      emit
        Diagnostic.
          {
            filename = source.filename;
            rule = rule.id;
            message;
            help = None;
            symbol = None;
            fixes = [];
            range = Source_range.of_location ~source:source.text location;
          })
    (rule.message names)

let check ?(context = Semantic_model.default_context) ~rules ~source tree =
  (* The compiler's iterator returns unit; keep accumulation local to this boundary. *)
  let diagnostics = ref [] in
  let emit diagnostic = diagnostics := diagnostic :: !diagnostics in
  let reference names location =
    List.iter (report ~source ~emit names location) rules
  in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression = inspect ~emit:reference;
      bound_value = (fun value -> { value with api = None; canonical = None });
    }
  in
  Semantic_walk.iter callbacks (initial context) tree;
  Source_range.sort (List.rev !diagnostics)
