module Names = Set.Make (String)

let family arity name =
  name :: (name ^ "Many")
  :: List.init (arity - 1) (fun index -> name ^ string_of_int (index + 2))

let modern_members =
  [
    "assert_";
    "assert2";
    "assert3";
    "assert4";
    "assert5";
    "assert6";
    "assertMany";
    "clear";
    "count";
    "countReset";
    "dir";
    "dirxml";
    "group";
    "groupCollapsed";
    "groupEnd";
    "table";
    "time";
    "timeEnd";
    "timeLog";
    "trace";
  ]
  @ List.concat_map (family 6) [ "debug"; "error"; "info"; "log"; "warn" ]

let legacy_members =
  [ "trace"; "timeStart"; "timeEnd"; "table" ]
  @ List.concat_map (family 4) [ "error"; "info"; "log"; "warn" ]

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let is_console = function
  | [ "Console"; member ]
  | [ "Stdlib"; "Console"; member ]
  | [ "Stdlib_Console"; member ] ->
      List.mem member modern_members
  | [ "Js"; "Console"; member ] | [ "Js_console"; member ] ->
      List.mem member legacy_members
  | [ "Js"; member ] -> List.mem member (family 4 "log")
  | _ -> false

let inspect ~(source : Source.t) ~shadowed ~emit
    (identifier : Longident.t Location.loc) =
  match path identifier.txt with
  | Some (root :: _ as names)
    when (not (Names.mem root shadowed)) && is_console names ->
      emit
        Diagnostic.
          {
            filename = source.filename;
            rule = "no-console";
            message = "Do not use " ^ String.concat "." names ^ ".";
            range = Source_range.of_location ~source:source.text identifier.loc;
          }
  | _ -> ()

let bind shadowed (binding : Parsetree.module_binding) =
  Names.add binding.pmb_name.txt shadowed

let rec iterator ~source ~emit shadowed : Ast_iterator.iterator =
  let default = Ast_iterator.default_iterator in
  {
    default with
    structure = (fun _ items -> structure ~source ~emit shadowed items);
    expr =
      (fun self expression ->
        match expression.Parsetree.pexp_desc with
        | Pexp_ident identifier -> inspect ~source ~shadowed ~emit identifier
        | Pexp_letmodule (name, binding, body) ->
            self.module_expr self binding;
            let nested = iterator ~source ~emit (Names.add name.txt shadowed) in
            nested.expr nested body
        | _ -> default.expr self expression);
    module_expr =
      (fun self expression ->
        match expression.Parsetree.pmod_desc with
        | Pmod_functor (name, parameter, body) ->
            Option.iter (self.module_type self) parameter;
            let nested = iterator ~source ~emit (Names.add name.txt shadowed) in
            nested.module_expr nested body
        | _ -> default.module_expr self expression);
    attributes = (fun _ _ -> ());
  }

and structure ~source ~emit shadowed = function
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
      let visitor = iterator ~source ~emit inside in
      visitor.structure_item visitor item;
      structure ~source ~emit after rest

let check ~source tree =
  (* The compiler's iterator returns unit; keep accumulation local to this boundary. *)
  let diagnostics = ref [] in
  let emit diagnostic = diagnostics := diagnostic :: !diagnostics in
  let visitor = iterator ~source ~emit Names.empty in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  Source_range.sort (List.rev !diagnostics)
