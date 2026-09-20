module Names = Set.Make (String)

type rule = { id : string; message : string list -> string option }

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let inspect ~emit shadowed (identifier : Longident.t Location.loc) =
  match path identifier.txt with
  | Some (root :: _ as names) when not (Names.mem root shadowed) ->
      emit names identifier.loc
  | _ -> ()

let bind shadowed (binding : Parsetree.module_binding) =
  Names.add binding.pmb_name.txt shadowed

let rec iterator ~emit shadowed : Ast_iterator.iterator =
  let default = Ast_iterator.default_iterator in
  {
    default with
    structure = (fun _ items -> structure ~emit shadowed items);
    expr =
      (fun self expression ->
        match expression.Parsetree.pexp_desc with
        | Pexp_ident identifier -> inspect ~emit shadowed identifier
        | Pexp_letmodule (name, binding, body) ->
            self.module_expr self binding;
            let nested = iterator ~emit (Names.add name.txt shadowed) in
            nested.expr nested body
        | _ -> default.expr self expression);
    module_expr =
      (fun self expression ->
        match expression.Parsetree.pmod_desc with
        | Pmod_functor (name, parameter, body) ->
            Option.iter (self.module_type self) parameter;
            let nested = iterator ~emit (Names.add name.txt shadowed) in
            nested.module_expr nested body
        | _ -> default.module_expr self expression);
    attributes = (fun _ _ -> ());
  }

and structure ~emit shadowed = function
  | [] -> ()
  | item :: rest ->
      let inside, after =
        match item.Parsetree.pstr_desc with
        | Pstr_module binding -> (shadowed, bind shadowed binding)
        | Pstr_recmodule bindings ->
            let bound = List.fold_left bind shadowed bindings in
            (bound, bound)
        | _ -> (shadowed, shadowed)
      in
      let visitor = iterator ~emit inside in
      visitor.structure_item visitor item;
      structure ~emit after rest

let report ~(source : Source.t) ~emit names location rule =
  Option.iter
    (fun message ->
      emit
        Diagnostic.
          {
            filename = source.filename;
            rule = rule.id;
            message;
            range = Source_range.of_location ~source:source.text location;
          })
    (rule.message names)

let check ~rules ~source tree =
  (* The compiler's iterator returns unit; keep accumulation local to this boundary. *)
  let diagnostics = ref [] in
  let emit diagnostic = diagnostics := diagnostic :: !diagnostics in
  let reference names location =
    List.iter (report ~source ~emit names location) rules
  in
  let visitor = iterator ~emit:reference Names.empty in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  Source_range.sort (List.rev !diagnostics)
